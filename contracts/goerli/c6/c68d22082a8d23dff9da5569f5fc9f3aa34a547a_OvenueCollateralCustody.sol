// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "../upgradeable/BaseUpgradeablePausable.sol";
import "../interfaces/IOvenueConfig.sol";
import "../interfaces/IOvenueFactory.sol";
import "../interfaces/IOvenueCollateralCustody.sol";
import "../interfaces/IOvenueExchange.sol";

import "../interfaces/IV2OvenueCreditLine.sol";
import "../libraries/OvenueConfigHelper.sol";
import "../libraries/OvenueExchangeHelper.sol";
import "../libraries/OvenueCollateralCustodyLogic.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IAccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract OvenueCollateralCustody is
    BaseUpgradeablePausable,
    IERC721Receiver,
    IOvenueCollateralCustody
{
    using OvenueConfigHelper for IOvenueConfig;
    using SafeERC20Upgradeable for IERC20withDec;

    // ------------- ERROR -----------------
    error UnauthorizedCaller();
    error WrongNFTCollateral();
    error CollateralAlreadyInitialized(address poolAddr);
    error PoolNotExisted(address poolAddr);
    error ConfigNotSetup();
    error InvalidAmount();
    error InLockupPeriod();
    error PoolNotEligibleForLiquidation();
    error InvalidPoolGovernor();
    error NFTListingMismatched();
    error NFTAlreadyInLiquidationProcess();
    error NFTNotLocked();
    error NoListingOrderToCancel();
    error ListingOrderAlreadyExists();
    error OrderHashMismatched();
    error NFTNotLiquidated();
    error NotExceedsLatenessGracePeriod();

    uint public constant SECONDS_IN_DAY = 1 days;
    uint public constant INVERSE_BASIS_POINT = 10000;
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

    IOvenueConfig public config;
    IOvenueExchange public exchange;

    // mapping(address => mapping(uint => IOvenueJuniorPool)) public lockedNftCollaterals;
    mapping(IOvenueJuniorPool => Collateral) public poolCollaterals;
    mapping(IOvenueJuniorPool => CollateralStatus) public poolCollateralStatus;
    mapping(IOvenueJuniorPool => NFTLiquidationOrder) public poolNFTCollateralLiquidation;

    event OvenueExchangeUpdated(address indexed who, address exchangeAddress);
    event OvenueConfigUpdated(address indexed who, address configAddress);
    event CollateralStatsCreated(
        address indexed nftAddr,
        uint256 tokenId,
        uint256 collateralAmount
    );
    event NFTCollateralLocked(
        address indexed nftAddr,
        uint256 tokenId,
        address indexed poolAddr
    );
    event FungibleCollateralCollected(
        address indexed poolAddr,
        uint256 funded,
        uint256 amount
    );
    event NFTCollateralRedeemed(
        address indexed poolAddr,
        address indexed nftAddr,
        uint256 tokenId
    );
    event FungibleCollateralRedeemed(address indexed poolAddr, uint256 amount);
    event NFTLiquidationStarted(address indexed poolAddr, bytes32 orderhash, uint64 timestamp);
    event NFTLiquidationCancelled(address indexed poolAddr, bytes32 orderhash, uint64 timestamp);

    function initialize(address owner, address _config) public initializer {
        __BaseUpgradeablePausable__init(owner);
        config = IOvenueConfig(_config);
        exchange = config.getOvenueExchange();
        IERC20Upgradeable(config.getUSDC()).approve(address(exchange), type(uint256).max);
    }

    // ------------- NFT MARKETPLACE (LIQUIDATION) -----------
    function recoverLossFundsForInvestors(
        address poolAddr,
        bool usingFungible
    ) external {
        IOvenueJuniorPool pool = IOvenueJuniorPool(poolAddr);

        NFTLiquidationOrder memory liquidationOrder = poolNFTCollateralLiquidation[pool];
        
        Collateral storage collateral = poolCollaterals[
            pool
        ];
        CollateralStatus storage collateralStatus = poolCollateralStatus[
            pool
        ];

        OvenueCollateralCustodyLogic.recoverLossFundsForInvestors(
            config, 
            pool, 
            exchange, 
            liquidationOrder, 
            collateral, 
            collateralStatus, 
            usingFungible
        );
    }
    
    function listNFTToMarketplace(
        address poolAddr,
        address[6] memory addrs,
        uint256[6] memory uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        IOvenueExchange.HowToCall howToCall,
        bytes memory callData,
        bytes memory replacementPattern,
        bool orderbookInclusionDesired
    ) external {
        IOvenueJuniorPool pool = IOvenueJuniorPool(poolAddr);

        // Check if latesness grace period is passed
        if (!eligibleForLiquidation(pool)) {
            revert PoolNotEligibleForLiquidation();
        }

        // get nFT Address from array
        address nftAddr = addrs[4];

        uint256 tokenId = _checkEligibleFromGovernor(
            poolAddr,
            nftAddr,
            callData
        );

         // Check if pool is already in liquidation process
        _checkPoolInLiquidation(pool);

        // _notExceedsLatenessGracePeriod(pool);

        // Get the hash of order to save for validation later on
        bytes32 orderHash = OvenueExchangeHelper.hashToSignRaw(
            addrs,
            uints,
            side,
            saleKind,
            howToCall,
            callData,
            replacementPattern
        );


        NFTLiquidationOrder memory liquidationOrder = poolNFTCollateralLiquidation[IOvenueJuniorPool(poolAddr)];

        if (liquidationOrder.orderHash != bytes32(0)) {
            revert ListingOrderAlreadyExists();
        }

        // Create pool liquidation status
        _createPoolLiquidation(
            poolAddr,
            orderHash,
            uints[0],
            uints[2]
        );
        
        IERC721Upgradeable(nftAddr).approve(address(exchange), tokenId);
        
        

        exchange.approveOrder_(
            addrs,
            uints,
            side,
            saleKind,
            howToCall,
            callData,
            replacementPattern,
            orderbookInclusionDesired
        );

        emit NFTLiquidationStarted(
            poolAddr,
            orderHash,
            uint64(block.timestamp)
        );
    }

    function cancelListingNFTMarketplace(
        address poolAddr,
        address[6] memory addrs,
        uint256[6] memory uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        IOvenueExchange.HowToCall howToCall,
        bytes memory callData,
        bytes memory replacementPattern,
        bool orderbookInclusionDesired
    ) external {
        // NFT - Addr
        address nftAddr = addrs[4];

        uint256 tokenId = _checkEligibleFromGovernor(
            poolAddr,
            nftAddr,
            callData
        );

        bytes32 orderHash = OvenueExchangeHelper.hashToSignRaw(
            addrs,
            uints,
            side,
            saleKind,
            howToCall,
            callData,
            replacementPattern
        );

        NFTLiquidationOrder memory liquidationOrder = poolNFTCollateralLiquidation[IOvenueJuniorPool(poolAddr)];

        if (liquidationOrder.orderHash == bytes32(0)) {
            revert NoListingOrderToCancel();
        }

        if (liquidationOrder.orderHash != orderHash) {
            revert OrderHashMismatched();
        }

        IERC721Upgradeable(nftAddr).approve(address(0), tokenId);
        
        exchange.cancelOrder_(
            addrs,
            uints,
            side,
            saleKind,
            howToCall,
            callData,
            replacementPattern,
            0,
            "",
            ""
        );

        emit NFTLiquidationCancelled(
            poolAddr,
            orderHash,
            uint64(block.timestamp)
        ); 

        CollateralStatus storage collateralStatus = poolCollateralStatus[
            IOvenueJuniorPool(poolAddr)
        ];

        collateralStatus.inLiquidationProcess = false;

        delete poolNFTCollateralLiquidation[IOvenueJuniorPool(poolAddr)];
    }

    function createCollateralStats(
        IOvenueJuniorPool _poolAddr,
        address _nftAddr,
        address _governor,
        uint256 _tokenId,
        uint256 _fungibleAmount
    ) external override onlyFactory {
        Collateral storage collateral = poolCollaterals[_poolAddr];
        CollateralStatus storage collateralStatus = poolCollateralStatus[
            _poolAddr
        ];

        if (collateral.nftAddr != address(0)) {
            revert CollateralAlreadyInitialized(address(_poolAddr));
        }

        collateral.nftAddr = _nftAddr;
        collateral.tokenId = _tokenId;
        collateral.fungibleAmount = _fungibleAmount;
        collateral.governor = _governor;

        collateralStatus.inLiquidationProcess = false;
        collateralStatus.nftLocked = false;
        collateralStatus.fundedFungibleAmount = 0;
        collateralStatus.fundedNonfungibleAmount = 0;

        emit CollateralStatsCreated(_nftAddr, _tokenId, _fungibleAmount);
    }

    function collectFungibleCollateral(
        IOvenueJuniorPool _poolAddr,
        address _depositor,
        uint256 _amount
    ) external override {
        if (_amount == 0) {
            revert InvalidAmount();
        }

        _checkPoolExisted(_poolAddr);

        if (
            !IAccessControlUpgradeable(address(_poolAddr)).hasRole(
                LOCKER_ROLE,
                msg.sender
            )
        ) {
            revert UnauthorizedCaller();
        }

        if (address(config) == address(0)) {
            revert ConfigNotSetup();
        }

        CollateralStatus storage collateralStatus = poolCollateralStatus[
            _poolAddr
        ];

        collateralStatus.fundedFungibleAmount += _amount;
        collateralStatus.lockedUntil =
            config.getCollateraLockupPeriod() +
            block.timestamp;

        config.getCollateralToken().safeTransferFrom(
            _depositor,
            address(this),
            _amount
        );

        // totalFungibleCollateralAmount += amount;

        emit FungibleCollateralCollected(
            address(_poolAddr),
            collateralStatus.fundedFungibleAmount,
            _amount
        );
    }

    function redeemAllCollateral(IOvenueJuniorPool _poolAddr, address receiver)
        external
        override
    {
        _checkPoolExisted(_poolAddr);
        _checkPoolInLiquidation(IOvenueJuniorPool(_poolAddr));

        if (
            !IAccessControlUpgradeable(address(_poolAddr)).hasRole(
                LOCKER_ROLE,
                msg.sender
            )
        ) {
            revert UnauthorizedCaller();
        }

        CollateralStatus storage collateralStatus = poolCollateralStatus[
            _poolAddr
        ];
        Collateral storage collateral = poolCollaterals[_poolAddr];

        /// @dev: check if lock up period is passed
        if (block.timestamp <= collateralStatus.lockedUntil) {
            revert InLockupPeriod();
        }

        if (collateralStatus.nftLocked) {
            address nftAddr = collateral.nftAddr;
            uint256 tokenId = collateral.tokenId;

            collateralStatus.nftLocked = false;

            IERC721Upgradeable(collateral.nftAddr).approve(address(0), tokenId);

            IERC721Upgradeable(nftAddr).safeTransferFrom(
                address(this),
                receiver,
                tokenId,
                ""
            );
            emit NFTCollateralRedeemed(address(_poolAddr), nftAddr, tokenId);
        }

        if (collateralStatus.fundedFungibleAmount > 0) {
            uint256 fundedFungibleAmount = collateralStatus
                .fundedFungibleAmount;

            config.getCollateralToken().safeTransfer(
                receiver,
                fundedFungibleAmount
            );
            collateralStatus.fundedFungibleAmount = 0;

            emit FungibleCollateralRedeemed(
                address(_poolAddr),
                fundedFungibleAmount
            );
        }
    }

    function updateOvenueConfig() external onlyAdmin {
        config = IOvenueConfig(config.configAddress());
        emit OvenueConfigUpdated(msg.sender, address(config));
    }

    function updateOvenueExchange() external onlyAdmin {
        exchange = IOvenueExchange(config.exchangeAddress());
        emit OvenueExchangeUpdated(msg.sender, address(exchange));
    }

    // function updateOvenueFactory() external onlyAdmin {
    //     factory = IOvenueFactory(config.ovenueFactoryAddress());
    //     emit OvenueFactoryUpdated(msg.sender, address(factory));
    // }

    function eligibleForLiquidation(
        IOvenueJuniorPool pool 
    ) public view returns(bool) {
        IV2OvenueCreditLine creditLine = pool.creditLine();
        uint loanBalance = creditLine.balance();
        return (
            creditLine.lastFullPaymentTime() + config.getLatenessGracePeriodInDays() * SECONDS_IN_DAY < block.timestamp
        ) && (loanBalance > 0);
    }

    function isCollateralFullyFunded(IOvenueJuniorPool _poolAddr)
        public
        view
        override
        returns (bool)
    {
        CollateralStatus storage collateralStatus = poolCollateralStatus[
            _poolAddr
        ];
        Collateral storage collateral = poolCollaterals[_poolAddr];

        return
            collateralStatus.nftLocked &&
            collateralStatus.fundedFungibleAmount >= collateral.fungibleAmount;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        address poolAddr = abi.decode(data, (address));

        Collateral storage collateral = poolCollaterals[
            IOvenueJuniorPool(poolAddr)
        ];
        CollateralStatus storage collateralStatus = poolCollateralStatus[
            IOvenueJuniorPool(poolAddr)
        ];

        _checkPoolExisted(IOvenueJuniorPool(poolAddr));

        if (
            !(msg.sender == collateral.nftAddr && tokenId == collateral.tokenId)
        ) {
            revert WrongNFTCollateral();
        }

        collateralStatus.nftLocked = true;
        collateralStatus.lockedUntil =
            config.getCollateraLockupPeriod() +
            block.timestamp;

        emit NFTCollateralLocked(msg.sender, tokenId, poolAddr);

        return IERC721Receiver.onERC721Received.selector;
    }

    function _createPoolLiquidation(
        address poolAddr,
        bytes32 orderHash,
        uint256 makerFee,
        uint256 price
    ) internal {
        poolNFTCollateralLiquidation[IOvenueJuniorPool(poolAddr)] = NFTLiquidationOrder({
            orderHash: orderHash,
            makerFee: makerFee,
            price: price,
            listAt: uint64(block.timestamp),
            fullfilled: false
        });

        CollateralStatus storage collateralStatus = poolCollateralStatus[
            IOvenueJuniorPool(poolAddr)
        ];

        collateralStatus.inLiquidationProcess = true;
    }

    /**
        @dev Check the encoded calldata from governance and whether it's a valid governor
    */
    function _checkEligibleFromGovernor(
        address poolAddr,
        address nftAddr,
        bytes memory callData
    ) internal view returns (uint256 tokenId) {
        address from;

        assembly {
            let length := mload(callData)
            tokenId := mload(add(callData, length))
            from := mload(add(callData, 0x24))
        }

        Collateral storage collateral = poolCollaterals[
            IOvenueJuniorPool(poolAddr)
        ];
        // CollateralStatus storage collateralStatus = poolCollateralStatus[
        //     IOvenueJuniorPool(poolAddr)
        // ];

        if (collateral.governor != msg.sender) {
            revert InvalidPoolGovernor();
        }

        if (
            nftAddr != collateral.nftAddr ||
            tokenId != collateral.tokenId ||
            from != address(this)
        ) {
            revert NFTListingMismatched();
        }
    }

    // function _notExceedsLatenessGracePeriod(IOvenueJuniorPool poolAddr) internal view {
    //     IV2OvenueCreditLine creditLine = poolAddr.creditLine();

    //     if (creditLine.lastFullPaymentTime() + config.getLatenessGracePeriodInDays() * SECONDS_IN_DAY > block.timestamp) {
    //         revert NotExceedsLatenessGracePeriod();
    //     }
    // }

    function _checkPoolInLiquidation(IOvenueJuniorPool poolAddr) internal view {
        CollateralStatus storage collateralStatus = poolCollateralStatus[
            poolAddr
        ];

        if (collateralStatus.inLiquidationProcess) {
            revert NFTAlreadyInLiquidationProcess();
        }
    }

    function _checkPoolExisted(IOvenueJuniorPool poolAddr) internal view {
        Collateral storage collateral = poolCollaterals[poolAddr];

        if (collateral.nftAddr == address(0)) {
            revert PoolNotExisted(address(poolAddr));
        }
    }

    modifier onlyFactory() {
        if (msg.sender != address(config.getOvenueFactory())) {
            revert UnauthorizedCaller();
        }
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title BaseUpgradeablePausable contract
 * @notice This is our Base contract that most other contracts inherit from. It includes many standard
 *  useful abilities like upgradeability, pausability, access control, and re-entrancy guards.
 * @author Goldfinch
 */

contract BaseUpgradeablePausable is
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // Pre-reserving a few slots in the base contract in case we need to add things in the future.
    // This does not actually take up gas cost or storage cost, but it does reserve the storage slots.
    // See OpenZeppelin's use of this pattern here:
    // https://github.com/OpenZeppelin/openzeppelin-contracts-ethereum-package/blob/master/contracts/GSN/Context.sol#L37
    uint256[50] private __gap1;
    uint256[50] private __gap2;
    uint256[50] private __gap3;
    uint256[50] private __gap4;

    // solhint-disable-next-line func-name-mixedcase
    function __BaseUpgradeablePausable__init(address owner) public onlyInitializing {
        require(owner != address(0), "Owner cannot be the zero address");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setupRole(OWNER_ROLE, owner);
        _setupRole(PAUSER_ROLE, owner);

        _setRoleAdmin(PAUSER_ROLE, OWNER_ROLE);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
    }

    function isAdmin() public view returns (bool) {
        return hasRole(OWNER_ROLE, _msgSender());
    }

    modifier onlyAdmin() {
        require(isAdmin(), "Must have admin role to perform this action");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./IOvenueJuniorPool.sol";

interface IOvenueCollateralCustody {
    struct Collateral {
        address nftAddr;
        address governor;
        uint256 tokenId;
        uint256 fungibleAmount;
    }

    struct CollateralStatus {
        uint256 lockedUntil;
        uint256 fundedFungibleAmount;
        uint256 fundedNonfungibleAmount;
        bool nftLocked;
        bool inLiquidationProcess;
    }

    struct NFTLiquidationOrder {
        bytes32 orderHash;
        uint256 price;
        uint256 makerFee;
        uint64 listAt;
        bool fullfilled;
    }
    
    function isCollateralFullyFunded(IOvenueJuniorPool _poolAddr) external returns(bool);
    function createCollateralStats(
        IOvenueJuniorPool _poolAddr,
        address _nftAddr,
        address _governor,
        uint256 _tokenId,
        uint256 _fungibleAmount
    ) external;
    
    function collectFungibleCollateral(
        IOvenueJuniorPool _poolAddr,
        address _depositor,
        uint256 _amount
    ) external;

    function redeemAllCollateral(
        IOvenueJuniorPool _poolAddr,
        address receiver
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IOvenueConfig {
  function getNumber(uint256 index) external view returns (uint256);

  function getAddress(uint256 index) external view returns (address);

  function setAddress(uint256 index, address newAddress) external returns (address);

  function setNumber(uint256 index, uint256 newNumber) external returns (uint256);

  function goList(address account) external view returns(bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IOvenueFactory {
  function createCreditLine() external returns (address);

  function createBorrower(address owner) external returns (address);

  function createPool(
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256[] calldata _allowedUIDTypes
  ) external returns (address);

  function createMigratedPool(
    address _borrower,
    uint256 _juniorFeePercent,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256[] calldata _allowedUIDTypes
  ) external returns (address);

  function updateGoldfinchConfig() external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "../libraries/SaleKindInterface.sol";

interface IOvenueExchange {
    enum HowToCall { Call, Delegate }

    function approveOrder_(
        address[6] memory addrs,
        uint[6] memory uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        HowToCall howToCall,
        bytes memory callData,
        bytes memory replacementPattern,
        bool orderbookInclusionDesired
    ) external;
    
    function cancelOrder_(
        address[6] memory addrs,
        uint[6] memory uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        HowToCall howToCall,
        bytes memory callData,
        bytes memory replacementPattern,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function cancelledOrFinalized(
        bytes32 orderHash
    ) external view returns(bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./IOvenueCreditLine.sol";

abstract contract IV2OvenueCreditLine is IOvenueCreditLine {
  function principal() external view virtual returns (uint256);

  function totalInterestAccrued() external view virtual returns (uint256);

  function termStartTime() external view virtual returns (uint256);

  function setLimit(uint256 newAmount) external virtual;

  function setMaxLimit(uint256 newAmount) external virtual;

  function setBalance(uint256 newBalance) external virtual;

  function setPrincipal(uint256 _principal) external virtual;

  function setTotalInterestAccrued(uint256 _interestAccrued) external virtual;

  function drawdown(uint256 amount) external virtual;

  function assess()
    external
    virtual
    returns (
      uint256,
      uint256,
      uint256
    );

  function initialize(
    address _config,
    address owner,
    address _borrower,
    uint256 _limit,
    uint256 _interestApr,
    uint256 _paymentPeriodInDays,
    uint256 _termInDays,
    uint256 _lateFeeApr,
    uint256 _principalGracePeriodInDays
  ) public virtual;

  function setTermEndTime(uint256 newTermEndTime) external virtual;

  function setNextDueTime(uint256 newNextDueTime) external virtual;

  function setInterestOwed(uint256 newInterestOwed) external virtual;

  function setPrincipalOwed(uint256 newPrincipalOwed) external virtual;

  function setInterestAccruedAsOf(uint256 newInterestAccruedAsOf) external virtual;

  function setWritedownAmount(uint256 newWritedownAmount) external virtual;

  function setLastFullPaymentTime(uint256 newLastFullPaymentTime) external virtual;

  function setLateFeeApr(uint256 newLateFeeApr) external virtual;
}

import "./ArrayUtils.sol";
import "./SaleKindInterface.sol";
import "../interfaces/IOvenueExchange.sol";

library OvenueExchangeHelper {
    struct Order {
        address exchange;
        /* Order maker address. */
        address maker;
        /* Order taker address, if specified. */
        address taker;
        /* Maker relayer fee of the order, unused for taker order. */
        uint256 makerRelayerFee;
        /* Taker relayer fee of the order, or maximum taker fee for a taker order. */
        uint256 takerRelayerFee;
        /* Order fee recipient or zero address for taker order. */
        address feeRecipient;
        /* Side (buy/sell). */
        SaleKindInterface.Side side;
        /* Kind of sale. */
        SaleKindInterface.SaleKind saleKind;
        IOvenueExchange.HowToCall howToCall;
        /* Target. */
        address target;
        /* Calldata. */
        bytes callData;
        bytes replacementPattern;
        /* Token used to pay for the order, or the zero-address as a sentinel value for Ether. */
        address paymentToken;
        /* Base price of the order (in paymentTokens). */
        uint256 basePrice;
        /* Listing timestamp. */
        uint256 listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint256 expirationTime;
        /* Order salt, used to prevent duplicate hashes. */
        uint256 salt;
    }
    
    /**
     * Calculate size of an order struct when tightly packed
     *
     * @param order Order to calculate size of
     * @return Size in bytes
     */
    function sizeOf(Order memory order)
    internal
    pure
    returns (uint)
    {
        return ((0x14 * 6) + (0x20 * 6) + 3 + order.callData.length + order.replacementPattern.length);
        // return ((0x14 * 6) + (0x20 * 9) + 4 + order.callData.length + order.replacementPattern.length + order.staticExtradata.length);
    }
    
    function hashOrder(Order memory order)
    internal
    pure
    returns (bytes32 hash)
    {
        /* Unfortunately abi.encodePacked doesn't work here, stack size constraints. */
        uint size = sizeOf(order);
        bytes memory array = new bytes(size);
        uint index;
        assembly {
            index := add(array, 0x20)
        }
        index = ArrayUtils.unsafeWriteAddress(index, order.exchange);
        index = ArrayUtils.unsafeWriteAddress(index, order.maker);
        index = ArrayUtils.unsafeWriteAddress(index, order.taker);
        index = ArrayUtils.unsafeWriteUint(index, order.makerRelayerFee);
        index = ArrayUtils.unsafeWriteUint(index, order.takerRelayerFee);
        index = ArrayUtils.unsafeWriteAddress(index, order.feeRecipient);
        index = ArrayUtils.unsafeWriteUint8(index, uint8(order.side));
        index = ArrayUtils.unsafeWriteUint8(index, uint8(order.saleKind));
        index = ArrayUtils.unsafeWriteUint8(index, uint8(order.howToCall));
        index = ArrayUtils.unsafeWriteAddress(index, order.target);
        index = ArrayUtils.unsafeWriteBytes(index, order.callData);
        index = ArrayUtils.unsafeWriteBytes(index, order.replacementPattern);
        index = ArrayUtils.unsafeWriteAddress(index, order.paymentToken);
        index = ArrayUtils.unsafeWriteUint(index, order.basePrice);
        index = ArrayUtils.unsafeWriteUint(index, order.listingTime);
        index = ArrayUtils.unsafeWriteUint(index, order.expirationTime);
        index = ArrayUtils.unsafeWriteUint(index, order.salt);
        assembly {
            hash := keccak256(add(array, 0x20), size)
        }
        return hash;
    }

    /**
     * @dev Hash an order, returning the hash that a client must sign, including the standard message prefix
     * @param order Order to hash
     * @return Hash of message prefix and order hash per Ethereum format
     */
    function hashToSign(Order memory order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    hashOrder(order)
                )
            );
    }

    function hashToSignRaw(
        address[6] memory addrs,
        uint[6] memory uints,
        SaleKindInterface.Side side,
        SaleKindInterface.SaleKind saleKind,
        IOvenueExchange.HowToCall howToCall,
        bytes memory callData,
        bytes memory replacementPattern
    ) external pure returns(bytes32) {
        Order memory order = Order(
            addrs[0],
            addrs[1],
            addrs[2],
            uints[0],
            uints[1],
            addrs[3],
            side,
            saleKind,
            howToCall,
            addrs[4],
            callData,
            replacementPattern,
            addrs[5],
            uints[2],
            uints[3],
            uints[4],
            uints[5]
        );

        return hashToSign(order);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// import {ImplementationRepository} from "./proxy/ImplementationRepository.sol";
import {OvenueConfigOptions} from "../core/OvenueConfigOptions.sol";

import {IOvenueCollateralCustody} from "../interfaces/IOvenueCollateralCustody.sol";

import {IOvenueConfig} from "../interfaces/IOvenueConfig.sol";
import {IOvenueSeniorLP} from "../interfaces/IOvenueSeniorLP.sol";
import {IOvenueSeniorPool} from "../interfaces/IOvenueSeniorPool.sol";
import {IOvenueSeniorPoolStrategy} from "../interfaces/IOvenueSeniorPoolStrategy.sol";
import {IERC20withDec} from "../interfaces/IERC20withDec.sol";
// import {ICUSDCContract} from "../../interfaces/ICUSDCContract.sol";
import {IOvenueJuniorLP} from "../interfaces/IOvenueJuniorLP.sol";
import {IOvenueJuniorRewards} from "../interfaces/IOvenueJuniorRewards.sol";
import {IOvenueFactory} from "../interfaces/IOvenueFactory.sol";
import {IGo} from "../interfaces/IGo.sol";

import {IOvenueExchange} from "../interfaces/IOvenueExchange.sol";

// import {IStakingRewards} from "../../interfaces/IStakingRewards.sol";
// import {ICurveLP} from "../../interfaces/ICurveLP.sol";

/**
 * @title ConfigHelper
 * @notice A convenience library for getting easy access to other contracts and constants within the
 *  protocol, through the use of the OvenueConfig contract
 * @author Goldfinch
 */

library OvenueConfigHelper {
  function getSeniorPool(IOvenueConfig config) internal view returns (IOvenueSeniorPool) {
    return IOvenueSeniorPool(seniorPoolAddress(config));
  }

  function getSeniorPoolStrategy(IOvenueConfig config) internal view returns (IOvenueSeniorPoolStrategy) {
    return IOvenueSeniorPoolStrategy(seniorPoolStrategyAddress(config));
  }

  function getUSDC(IOvenueConfig config) internal view returns (IERC20withDec) {
    return IERC20withDec(usdcAddress(config));
  }

  function getSeniorLP(IOvenueConfig config) internal view returns (IOvenueSeniorLP) {
    return IOvenueSeniorLP(fiduAddress(config));
  }

//   function getFiduUSDCCurveLP(OvenueConfig config) internal view returns (ICurveLP) {
//     return ICurveLP(fiduUSDCCurveLPAddress(config));
//   }

//   function getCUSDCContract(OvenueConfig config) internal view returns (ICUSDCContract) {
//     return ICUSDCContract(cusdcContractAddress(config));
//   }

  function getJuniorLP(IOvenueConfig config) internal view returns (IOvenueJuniorLP) {
    return IOvenueJuniorLP(juniorLPAddress(config));
  }

  function getJuniorRewards(IOvenueConfig config) internal view returns (IOvenueJuniorRewards) {
    return IOvenueJuniorRewards(juniorRewardsAddress(config));
  }

  function getOvenueFactory(IOvenueConfig config) internal view returns (IOvenueFactory) {
    return IOvenueFactory(ovenueFactoryAddress(config));
  }

  function getOVN(IOvenueConfig config) internal view returns (IERC20withDec) {
    return IERC20withDec(ovenueAddress(config));
  }

  function getGo(IOvenueConfig config) internal view returns (IGo) {
    return IGo(goAddress(config));
  }

  function getCollateralToken(IOvenueConfig config) internal view returns (IERC20withDec) {
    return IERC20withDec(collateralTokenAddress(config));
  }

  function getCollateralCustody(IOvenueConfig config) internal view returns (IOvenueCollateralCustody) {
    return IOvenueCollateralCustody(collateralCustodyAddress(config));
  }

  function getOvenueExchange(IOvenueConfig config) internal view returns (IOvenueExchange) {
    return IOvenueExchange(exchangeAddress(config));
  }

//   function getStakingRewards(OvenueConfig config) internal view returns (IStakingRewards) {
//     return IStakingRewards(stakingRewardsAddress(config));
//   }

  // function getTranchedPoolImplementationRepository(IOvenueConfig config)
  //   internal
  //   view
  //   returns (ImplementationRepository)
  // {
  //   return
  //     ImplementationRepository(
  //       config.getAddress(uint256(OvenueConfigOptions.Addresses.TranchedPoolImplementation))
  //     );
  // }

//   function oneInchAddress(OvenueConfig config) internal view returns (address) {
//     return config.getAddress(uint256(OvenueOvenueConfigOptions.Addresses.OneInch));
//   }

  function creditLineImplementationAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.CreditLineImplementation));
  }

//   /// @dev deprecated because we no longer use GSN
//   function trustedForwarderAddress(OvenueConfig config) internal view returns (address) {
//     return config.getAddress(uint256(OvenueOvenueConfigOptions.Addresses.TrustedForwarder));
//   }

function exchangeAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.OvenueExchange));
  }

  function collateralCustodyAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.CollateralCustody));
  }
  function configAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.OvenueConfig));
  }

  function juniorLPAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.PoolTokens));
  }

  function juniorRewardsAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.JuniorRewards));
  }

  function seniorPoolAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.SeniorPool));
  }

  function seniorPoolStrategyAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.SeniorPoolStrategy));
  }

  function ovenueFactoryAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.OvenueFactory));
  }

  function ovenueAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.OVENUE));
  }

  function fiduAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.Fidu));
  }

  function collateralTokenAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.CollateralToken));
  }

//   function fiduUSDCCurveLPAddress(OvenueConfig config) internal view returns (address) {
//     return config.getAddress(uint256(OvenueConfigOptions.Addresses.FiduUSDCCurveLP));
//   }

//   function cusdcContractAddress(OvenueConfig config) internal view returns (address) {
//     return config.getAddress(uint256(OvenueConfigOptions.Addresses.CUSDCContract));
//   }

  function usdcAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.USDC));
  }

  function collateralGovernanceAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.CollateralGovernanceImplementation));
  }

  function tranchedPoolAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.TranchedPoolImplementation));
  }

  function reserveAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.TreasuryReserve));
  }

  function protocolAdminAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.ProtocolAdmin));
  }

  function borrowerImplementationAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.BorrowerImplementation));
  }

  function goAddress(IOvenueConfig config) internal view returns (address) {
    return config.getAddress(uint256(OvenueConfigOptions.Addresses.Go));
  }

//   function stakingRewardsAddress(OvenueConfig config) internal view returns (address) {
//     return config.getAddress(uint256(OvenueConfigOptions.Addresses.StakingRewards));
//   }

  function getCollateraLockupPeriod(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.CollateralLockedUpInSeconds));
  }

  function getReserveDenominator(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.ReserveDenominator));
  }

  function getWithdrawFeeDenominator(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.WithdrawFeeDenominator));
  }

  function getLatenessGracePeriodInDays(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.LatenessGracePeriodInDays));
  }

  function getLatenessMaxDays(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.LatenessMaxDays));
  }

  function getDrawdownPeriodInSeconds(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.DrawdownPeriodInSeconds));
  }

  function getTransferRestrictionPeriodInDays(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.TransferRestrictionPeriodInDays));
  }

  function getLeverageRatio(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.LeverageRatio));
  }

  function getCollateralVotingPeriod(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.CollateralVotingPeriod));
  }

  function getCollateralVotingDelay(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.CollateralVotingDelay));
  }

  function getCollateralQuorumNumerator(IOvenueConfig config) internal view returns (uint256) {
    return config.getNumber(uint256(OvenueConfigOptions.Numbers.CollateralVotingQuorumNumerator));
  }
}

pragma solidity 0.8.5;

import "../interfaces/IOvenueCollateralCustody.sol";
import "../interfaces/IOvenueExchange.sol";
import "../interfaces/IOvenueConfig.sol";

import "../libraries/OvenueConfigHelper.sol";


library OvenueCollateralCustodyLogic {
    using OvenueConfigHelper for IOvenueConfig;

    error InvalidPoolGovernor();
    error NotExceedsLatenessGracePeriod();

    uint public constant INVERSE_BASIS_POINT = 10000;

    event JuniorPoolDebtRecover(
        address indexed poolAddr,
        uint256 totalOwned,
        uint256 timestamp
    );

    function recoverLossFundsForInvestors(
        IOvenueConfig config,
        IOvenueJuniorPool pool,
        IOvenueExchange exchange,
        IOvenueCollateralCustody.NFTLiquidationOrder memory liquidationOrder,
        IOvenueCollateralCustody.Collateral storage collateral,
        IOvenueCollateralCustody.CollateralStatus storage collateralStatus,
        bool usingFungible
    ) external {
        // if (collateral.governor != msg.sender) {
        //     revert InvalidPoolGovernor();
        // }

        // Check if latesness grace period is passed
        _notExceedsLatenessGracePeriod(pool, config);

        // Get total owned and get the condition of distribute liquidation
        IV2OvenueCreditLine creditLine = pool.creditLine();
        uint loanBalance = creditLine.balance();

        if (loanBalance > 0) {
            pool.assess();
        }

        uint totalOwned = creditLine.interestOwed() + creditLine.principalOwed();

        // check if liquidation amount of pool is still enough for covering debt
        if (!usingFungible) {
            bytes32 orderHash = liquidationOrder.orderHash;
            bool isFullfilled = exchange.cancelledOrFinalized(orderHash);
            
            if (!liquidationOrder.fullfilled && isFullfilled) {
                liquidationOrder.fullfilled = true;
                collateralStatus.fundedNonfungibleAmount = liquidationOrder.price * (INVERSE_BASIS_POINT - liquidationOrder.makerFee) / INVERSE_BASIS_POINT;
            }
            
            collateralStatus.fundedNonfungibleAmount -= totalOwned;
        } else {
            collateralStatus.fundedFungibleAmount -= totalOwned;
        }
        

        // Approve USDC for creditline contract for assessing
        config.getUSDC().approve(
            address(pool),
            totalOwned
        );

        pool.pay(
            totalOwned
        );

        emit JuniorPoolDebtRecover(
            address(pool),
            totalOwned,
            block.timestamp
        );
    }

    function _notExceedsLatenessGracePeriod(IOvenueJuniorPool poolAddr, IOvenueConfig config) internal view {
        IV2OvenueCreditLine creditLine = poolAddr.creditLine();

        if (creditLine.lastFullPaymentTime() + config.getLatenessGracePeriodInDays() > block.timestamp) {
            revert NotExceedsLatenessGracePeriod();
        }
    }
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
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

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

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
        _checkRole(role);
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
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
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
     *
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleRevoked} event.
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
     *
     * May emit a {RoleRevoked} event.
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
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleGranted} event.
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
     *
     * May emit a {RoleRevoked} event.
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
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
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
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
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
                /// @solidity memory-safe-assembly
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
pragma solidity 0.8.5;

import {IV2OvenueCreditLine} from "./IV2OvenueCreditLine.sol";

abstract contract IOvenueJuniorPool {
    IV2OvenueCreditLine public creditLine;
    uint256 public createdAt;

     struct Collateral {
        address nftAddr;
        uint tokenId;
        uint collateralAmount;
        bool isLocked;
    }

    enum Tranches {
        Reserved,
        Senior,
        Junior
    }

    struct TrancheInfo {
        uint256 id;
        uint256 principalDeposited;
        uint256 principalSharePrice;
        uint256 interestSharePrice;
        uint256 lockedUntil;
    }

    struct PoolSlice {
        TrancheInfo seniorTranche;
        TrancheInfo juniorTranche;
        uint256 totalInterestAccrued;
        uint256 principalDeployed;
        uint256 collateralDeposited;
    }

    function initialize(
        // config - borrower
        address[2] calldata _addresses,
        // junior fee percent - late fee apr, interest apr
        uint256[3] calldata _fees,
        // _paymentPeriodInDays - _termInDays - _principalGracePeriodInDays - _fundableAt
        uint256[4] calldata _days,
        uint256 _limit,
        uint256[] calldata _allowedUIDTypes
    ) external virtual;

    function getTranche(uint256 tranche)
        external
        view
        virtual
        returns (TrancheInfo memory);

    function pay(uint256 amount) external virtual;

    function poolSlices(uint256 index)
        external
        view
        virtual
        returns (PoolSlice memory);

    function cancel() external virtual;

    function setCancelStatus(bool status) external virtual;

    function lockJuniorCapital() external virtual;

    function lockPool() external virtual;

    function initializeNextSlice(uint256 _fundableAt) external virtual;

    function totalJuniorDeposits() external view virtual returns (uint256);

    function drawdown(uint256 amount) external virtual;

    function setFundableAt(uint256 timestamp) external virtual;

    function deposit(uint256 tranche, uint256 amount)
        external
        virtual
        returns (uint256 tokenId);

    function assess() external virtual;

    function depositWithPermit(
        uint256 tranche,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual returns (uint256 tokenId);

    function availableToWithdraw(uint256 tokenId)
        external
        view
        virtual
        returns (uint256 interestRedeemable, uint256 principalRedeemable);

    function withdraw(uint256 tokenId, uint256 amount)
        external
        virtual
        returns (uint256 interestWithdrawn, uint256 principalWithdrawn);

    function withdrawMax(uint256 tokenId)
        external
        virtual
        returns (uint256 interestWithdrawn, uint256 principalWithdrawn);

    function withdrawMultiple(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external virtual;

    // function claimCollateralNFT() external virtual;

    function numSlices() external view virtual returns (uint256);
    // function isCollateralLocked() external view virtual returns (bool);

    // function getCollateralInfo() external view virtual returns(address, uint, bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IOvenueCreditLine {
  function borrower() external view returns (address);

  function limit() external view returns (uint256);

  function maxLimit() external view returns (uint256);

  function interestApr() external view returns (uint256);

  function paymentPeriodInDays() external view returns (uint256);

  function principalGracePeriodInDays() external view returns (uint256);

  function termInDays() external view returns (uint256);

  function lateFeeApr() external view returns (uint256);

  function isLate() external view returns (bool);

  function withinPrincipalGracePeriod() external view returns (bool);

  // Accounting variables
  function balance() external view returns (uint256);

  function interestOwed() external view returns (uint256);

  function principalOwed() external view returns (uint256);

  function termEndTime() external view returns (uint256);

  function nextDueTime() external view returns (uint256);

  function interestAccruedAsOf() external view returns (uint256);

  function lastFullPaymentTime() external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.5;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library SaleKindInterface {

    /**
     * Side: buy or sell.
     */
    enum Side { Buy, Sell }

    /**
     * Currently supported kinds of sale: fixed price, Dutch auction.
     * English auctions cannot be supported without stronger escrow guarantees.
     * Future interesting options: Vickrey auction, nonlinear Dutch auctions.
     */
    enum SaleKind { FixedPrice, DutchAuction }

    /**
     * @dev Check whether the parameters of a sale are valid
     * @param saleKind Kind of sale
     * @param expirationTime Order expiration time
     * @return Whether the parameters were valid
     */
    function validateParameters(SaleKind saleKind, uint expirationTime)
    pure
    internal
    returns (bool)
    {
        /* Auctions must have a set expiration date. */
        return (saleKind == SaleKind.FixedPrice || expirationTime > 0);
    }

    /**
     * @dev Return whether or not an order can be settled
     * @dev Precondition: parameters have passed validateParameters
     * @param listingTime Order listing time
     * @param expirationTime Order expiration time
     */
    function canSettleOrder(uint listingTime, uint expirationTime)
    view
    internal
    returns (bool)
    {
        return (listingTime < block.timestamp) && (expirationTime == 0 || block.timestamp < expirationTime);
    }

    /**
     * @dev Calculate the settlement price of an order
     * @dev Precondition: parameters have passed validateParameters.
     * @param side Order side
     * @param saleKind Method of sale
     * @param basePrice Order base price
     * @param extra Order extra price data
     * @param listingTime Order listing time
     * @param expirationTime Order expiration time
     */
    function calculateFinalPrice(Side side, SaleKind saleKind, uint basePrice, uint extra, uint listingTime, uint expirationTime)
    view
    internal
    returns (uint finalPrice)
    {
        if (saleKind == SaleKind.FixedPrice) {
            return basePrice;
        }
        else if (saleKind == SaleKind.DutchAuction) {
            uint diff = SafeMath.div(SafeMath.mul(extra, SafeMath.sub(block.timestamp, listingTime)), SafeMath.sub(expirationTime, listingTime));
            if (side == Side.Sell) {
                /* Sell-side - start price: basePrice. End price: basePrice - extra. */
                return SafeMath.sub(basePrice, diff);
            } else {
                /* Buy-side - start price: basePrice. End price: basePrice + extra. */
                return SafeMath.add(basePrice, diff);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.5;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ArrayUtils
 * @author Wyvern Protocol Developers
 */
library ArrayUtils {

    /**
     * Replace bytes in an array with bytes in another array, guarded by a bitmask
     * Efficiency of this function is a bit unpredictable because of the EVM's word-specific model (arrays under 32 bytes will be slower)
     * Modifies the provided byte array parameter in place
     *
     * @dev Mask must be the size of the byte array. A nonzero byte means the byte array can be changed.
     * @param array The original array
     * @param desired The target array
     * @param mask The mask specifying which bits can be changed
     */
    function guardedArrayReplace(bytes memory array, bytes memory desired, bytes memory mask)
    internal
    pure
    {
        require(array.length == desired.length, "Arrays have different lengths");
        require(array.length == mask.length, "Array and mask have different lengths");

        uint words = array.length / 0x20;
        uint index = words * 0x20;
        assert(index / 0x20 == words);
        uint i;

        for (i = 0; i < words; i++) {
            /* Conceptually: array[i] = (!mask[i] && array[i]) || (mask[i] && desired[i]), bitwise in word chunks. */
            assembly {
                let commonIndex := mul(0x20, add(1, i))
                let maskValue := mload(add(mask, commonIndex))
                mstore(add(array, commonIndex), or(and(not(maskValue), mload(add(array, commonIndex))), and(maskValue, mload(add(desired, commonIndex)))))
            }
        }

        /* Deal with the last section of the byte array. */
        if (words > 0) {
            /* This overlaps with bytes already set but is still more efficient than iterating through each of the remaining bytes individually. */
            i = words;
            assembly {
                let commonIndex := mul(0x20, add(1, i))
                let maskValue := mload(add(mask, commonIndex))
                mstore(add(array, commonIndex), or(and(not(maskValue), mload(add(array, commonIndex))), and(maskValue, mload(add(desired, commonIndex)))))
            }
        } else {
            /* If the byte array is shorter than a word, we must unfortunately do the whole thing bytewise.
               (bounds checks could still probably be optimized away in assembly, but this is a rare case) */
            for (i = index; i < array.length; i++) {
                array[i] = ((mask[i] ^ 0xff) & array[i]) | (mask[i] & desired[i]);
            }
        }
    }

    /**
     * Test if two arrays are equal
     * Source: https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
     *
     * @dev Arrays must be of equal length, otherwise will return false
     * @param a First array
     * @param b Second array
     * @return Whether or not all bytes in the arrays are equal
     */
    function arrayEq(bytes memory a, bytes memory b)
    internal
    pure
    returns (bool)
    {
        bool success = true;

        assembly {
            let length := mload(a)

        // if lengths don't match the arrays are not equal
            switch eq(length, mload(b))
            case 1 {
            // cb is a circuit breaker in the for loop since there's
            //  no said feature for inline assembly loops
            // cb = 1 - don't breaker
            // cb = 0 - break
                let cb := 1

                let mc := add(a, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(b, 0x20)
                // the next line is the loop condition:
                // while(uint(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                    // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
            // unsuccess:
                success := 0
            }
        }

        return success;
    }

    /**
     * Drop the beginning of an array
     *
     * @param _bytes array
     * @param _start start index
     * @return Whether or not all bytes in the arrays are equal
     */
    function arrayDrop(bytes memory _bytes, uint _start)
    internal
    pure
    returns (bytes memory)
    {

        uint _length = SafeMath.sub(_bytes.length, _start);
        return arraySlice(_bytes, _start, _length);
    }

    /**
     * Take from the beginning of an array
     *
     * @param _bytes array
     * @param _length elements to take
     * @return Whether or not all bytes in the arrays are equal
     */
    function arrayTake(bytes memory _bytes, uint _length)
    internal
    pure
    returns (bytes memory)
    {

        return arraySlice(_bytes, 0, _length);
    }

    /**
     * Slice an array
     * Source: https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
     *
     * @param _bytes array
     * @param _start start index
     * @param _length length to take
     * @return Whether or not all bytes in the arrays are equal
     */
    function arraySlice(bytes memory _bytes, uint _start, uint _length)
    internal
    pure
    returns (bytes memory)
    {

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
                tempBytes := mload(0x40)

            // The first word of the slice result is potentially a partial
            // word read from the original array. To read it, we calculate
            // the length of that partial word and start copying that many
            // bytes into the array. The first word we copy will start with
            // data we don't care about, but the last `lengthmod` bytes will
            // land at the beginning of the contents of the new array. When
            // we're done copying, we overwrite the full first word with
            // the actual length of the slice.
                let lengthmod := and(_length, 31)

            // The multiplication in the next line is necessary
            // because when slicing multiples of 32 bytes (lengthmod == 0)
            // the following copy loop was copying the origin's length
            // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                // The multiplication in the next line has the same exact purpose
                // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

            //update free-memory pointer
            //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    /**
     * Unsafe write byte array into a memory location
     *
     * @param index Memory location
     * @param source Byte array to write
     * @return End memory index
     */
    function unsafeWriteBytes(uint index, bytes memory source)
    internal
    pure
    returns (uint)
    {
        if (source.length > 0) {
            assembly {
                let length := mload(source)
                let end := add(source, add(0x20, length))
                let arrIndex := add(source, 0x20)
                let tempIndex := index
                for { } eq(lt(arrIndex, end), 1) {
                    arrIndex := add(arrIndex, 0x20)
                    tempIndex := add(tempIndex, 0x20)
                } {
                    mstore(tempIndex, mload(arrIndex))
                }
                index := add(index, length)
            }
        }
        return index;
    }

    /**
     * Unsafe write address into a memory location
     *
     * @param index Memory location
     * @param source Address to write
     * @return End memory index
     */
    function unsafeWriteAddress(uint index, address source)
    internal
    pure
    returns (uint)
    {
        uint conv = uint(uint160(source)) << 0x60;
        assembly {
            mstore(index, conv)
            index := add(index, 0x14)
        }
        return index;
    }

    /**
     * Unsafe write uint into a memory location
     *
     * @param index Memory location
     * @param source uint to write
     * @return End memory index
     */
    function unsafeWriteUint(uint index, uint source)
    internal
    pure
    returns (uint)
    {
        assembly {
            mstore(index, source)
            index := add(index, 0x20)
        }
        return index;
    }

    /**
     * Unsafe write uint8 into a memory location
     *
     * @param index Memory location
     * @param source uint8 to write
     * @return End memory index
     */
    function unsafeWriteUint8(uint index, uint8 source)
    internal
    pure
    returns (uint)
    {
        assembly {
            mstore8(index, source)
            index := add(index, 0x1)
        }
        return index;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./IERC20withDec.sol";

interface IOvenueSeniorLP is IERC20withDec {
  function mintTo(address to, uint256 amount) external;

  function burnFrom(address to, uint256 amount) external;

  function renounceRole(bytes32 role, address account) external;

  function delegates(address account) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./IOvenueJuniorPool.sol";

abstract contract IOvenueSeniorPool {
  uint256 public sharePrice;
  uint256 public totalLoansOutstanding;
  uint256 public totalWritedowns;

  function deposit(uint256 amount) external virtual returns (uint256 depositShares);

  function depositWithPermit(
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual returns (uint256 depositShares);

  function withdraw(uint256 usdcAmount) external virtual returns (uint256 amount);

  function withdrawInLP(uint256 fiduAmount) external virtual returns (uint256 amount);

//   function sweepToCompound() public virtual;

//   function sweepFromCompound() public virtual;

  function invest(IOvenueJuniorPool pool) public virtual;

  function estimateInvestment(IOvenueJuniorPool pool) public view virtual returns (uint256);

  function redeem(uint256 tokenId) public virtual;

  function writedown(uint256 tokenId) public virtual;

  function calculateWritedown(uint256 tokenId) public view virtual returns (uint256 writedownAmount);

  function assets() public view virtual returns (uint256);

  function getNumShares(uint256 amount) public view virtual returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IOvenueJuniorLP is IERC721Upgradeable {
    event TokenPrincipalWithdrawn(
        address indexed owner,
        address indexed pool,
        uint256 indexed tokenId,
        uint256 principalWithdrawn,
        uint256 tranche
    );
    event TokenBurned(
        address indexed owner,
        address indexed pool,
        uint256 indexed tokenId
    );
    event TokenMinted(
        address indexed owner,
        address indexed pool,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 tranche
    );

    event TokenRedeemed(
        address indexed owner,
        address indexed pool,
        uint256 indexed tokenId,
        uint256 principalRedeemed,
        uint256 interestRedeemed,
        uint256 tranche
    );

    struct TokenInfo {
        address pool;
        uint256 tranche;
        uint256 principalAmount;
        uint256 principalRedeemed;
        uint256 interestRedeemed;
    }

    struct MintParams {
        uint256 principalAmount;
        uint256 tranche;
    }

    function mint(MintParams calldata params, address to)
        external
        returns (uint256);

    function redeem(
        uint256 tokenId,
        uint256 principalRedeemed,
        uint256 interestRedeemed
    ) external;

    function withdrawPrincipal(uint256 tokenId, uint256 principalAmount)
        external;

    function burn(uint256 tokenId) external;

    function onPoolCreated(address newPool) external;

    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (TokenInfo memory);

    function validPool(address sender) external view returns (bool);

    function isApprovedOrOwner(address spender, uint256 tokenId)
        external
        view
        returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20withDec is IERC20Upgradeable {
  /**
   * @dev Returns the number of decimals used for the token
   */
  function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

/**
 * @title ConfigOptions
 * @notice A central place for enumerating the configurable options of our GoldfinchConfig contract
 * @author Goldfinch
 */

library OvenueConfigOptions {
  // NEVER EVER CHANGE THE ORDER OF THESE!
  // You can rename or append. But NEVER change the order.
  enum Numbers {
    TransactionLimit, // 0
    /// @dev: TotalFundsLimit used to represent a total cap on senior pool deposits
    /// but is now deprecated
    TotalFundsLimit, // 1
    MaxUnderwriterLimit, // 2
    ReserveDenominator, // 3
    WithdrawFeeDenominator, // 4
    LatenessGracePeriodInDays, // 5
    LatenessMaxDays, // 6
    DrawdownPeriodInSeconds, // 7
    TransferRestrictionPeriodInDays, // 8
    LeverageRatio, // 9
    CollateralLockedUpInSeconds, // 10
    CollateralVotingDelay, // 11
    CollateralVotingPeriod, // 12
    CollateralVotingQuorumNumerator // 13,
  }
  /// @dev TrustedForwarder is deprecated because we no longer use GSN. CreditDesk
  ///   and Pool are deprecated because they are no longer used in the protocol.
  enum Addresses {
    CreditLineImplementation, // 0
    OvenueFactory, // 1
    Fidu, // 2
    USDC, // 3
    OVENUE, // 4
    TreasuryReserve, // 5
    ProtocolAdmin, // 6
    // OneInch,
    // CUSDCContract,
    OvenueConfig, // 7
    PoolTokens, // 8
    SeniorPool, // 9
    SeniorPoolStrategy, // 10
    TranchedPoolImplementation, // 11
    BorrowerImplementation, // 12
    // OVENUE, 
    Go, // 13
    JuniorRewards, // 14
    CollateralToken, // 15
    CollateralCustody, // 16
    CollateralGovernanceImplementation, // 17
    OvenueExchange // 18
    // StakingRewards
    // FiduUSDCCurveLP
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./IOvenueSeniorPool.sol";
import "./IOvenueJuniorPool.sol";

abstract contract IOvenueSeniorPoolStrategy {
//   function getLeverageRatio(IOvenueJuniorPool pool) public view virtual returns (uint256);
  function getLeverageRatio() public view virtual returns (uint256);

  function invest(IOvenueJuniorPool pool) public view virtual returns (uint256 amount);

  function estimateInvestment(IOvenueJuniorPool pool) public view virtual returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IOvenueJuniorRewards {
  function allocateRewards(uint256 _interestPaymentAmount) external;

  // function onTranchedPoolDrawdown(uint256 sliceIndex) external;

  function setPoolTokenAccRewardsPerPrincipalDollarAtMint(address poolAddress, uint256 tokenId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

abstract contract IGo {
  uint256 public constant ID_TYPE_0 = 0;
  uint256 public constant ID_TYPE_1 = 1;
  uint256 public constant ID_TYPE_2 = 2;
  uint256 public constant ID_TYPE_3 = 3;
  uint256 public constant ID_TYPE_4 = 4;
  uint256 public constant ID_TYPE_5 = 5;
  uint256 public constant ID_TYPE_6 = 6;
  uint256 public constant ID_TYPE_7 = 7;
  uint256 public constant ID_TYPE_8 = 8;
  uint256 public constant ID_TYPE_9 = 9;
  uint256 public constant ID_TYPE_10 = 10;

  /// @notice Returns the address of the UniqueIdentity contract.
  function uniqueIdentity() external virtual returns (address);

  function go(address account) public view virtual returns (bool);

  function goOnlyIdTypes(address account, uint256[] calldata onlyIdTypes) public view virtual returns (bool);

  function goSeniorPool(address account) public view virtual returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}