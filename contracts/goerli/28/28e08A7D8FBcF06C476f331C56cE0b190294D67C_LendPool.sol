// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ILendPoolLoan} from "../interfaces/ILendPoolLoan.sol";
import {ILendPool} from "../interfaces/ILendPool.sol";
import {ILendPoolAddressesProvider} from "../interfaces/ILendPoolAddressesProvider.sol";

import {Errors} from "../libraries/helpers/Errors.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {GenericLogic} from "../libraries/logic/GenericLogic.sol";
import {PercentageMath} from "../libraries/math/PercentageMath.sol";
import {ReserveLogic} from "../libraries/logic/ReserveLogic.sol";
import {NftLogic} from "../libraries/logic/NftLogic.sol";
import {ValidationLogic} from "../libraries/logic/ValidationLogic.sol";
import {SupplyLogic} from "../libraries/logic/SupplyLogic.sol";
import {BorrowLogic} from "../libraries/logic/BorrowLogic.sol";
import {LiquidateLogic} from "../libraries/logic/LiquidateLogic.sol";

import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
import {NftConfiguration} from "../libraries/configuration/NftConfiguration.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {LendPoolStorage} from "./LendPoolStorage.sol";
import {LendPoolStorageExt} from "./LendPoolStorageExt.sol";

import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC721ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @title LendPool contract
 * @dev Main point of interaction with an Confetti protocol's market
 * - Users can:
 *   # Deposit
 *   # Withdraw
 *   # Borrow
 *   # Repay
 *   # BuyItNow
 *   # Liquidate
 * - To be covered by a proxy contract, owned by the LendPoolAddressesProvider of the specific market
 * - All admin functions are callable by the LendPoolConfigurator contract defined also in the
 *   LendPoolAddressesProvider
 * @author Confetti
 **/
// !!! For Upgradable: DO NOT ADJUST Inheritance Order !!!
contract LendPool is
    Initializable,
    ILendPool,
    LendPoolStorage,
    ContextUpgradeable,
    IERC721ReceiverUpgradeable,
    LendPoolStorageExt
{
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ReserveLogic for DataTypes.ReserveData;
    using NftLogic for DataTypes.NftData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using NftConfiguration for DataTypes.NftConfigurationMap;

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

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    modifier onlyLendPoolConfigurator() {
        _onlyLendPoolConfigurator();
        _;
    }

    function _whenNotPaused() internal view {
        require(!_paused, Errors.LP_IS_PAUSED);
    }

    function _onlyLendPoolConfigurator() internal view {
        require(
            _addressesProvider.getLendPoolConfigurator() == _msgSender(),
            Errors.LP_CALLER_NOT_LEND_POOL_CONFIGURATOR
        );
    }

    /**
     * @dev Function is invoked by the proxy contract when the LendPool contract is added to the
     * LendPoolAddressesProvider of the market.
     * - Caching the address of the LendPoolAddressesProvider in order to reduce gas consumption
     *   on subsequent operations
     * @param provider The address of the LendPoolAddressesProvider
     **/
    function initialize(ILendPoolAddressesProvider provider)
        public
        initializer
    {
        _maxNumberOfReserves = 32;
        _maxNumberOfNfts = 256;

        _addressesProvider = provider;
    }

    /**
     * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying cTokens.
     * - E.g. User deposits 100 USDC and gets in return 100 bUSDC
     * @param asset The address of the underlying asset to deposit
     * @param amount The amount to be deposited
     * @param onBehalfOf The address that will receive the cTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of cTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external override nonReentrant whenNotPaused {
        SupplyLogic.executeDeposit(
            _reserves,
            DataTypes.ExecuteDepositParams({
                initiator: _msgSender(),
                asset: asset,
                amount: amount,
                onBehalfOf: onBehalfOf,
                referralCode: referralCode
            })
        );
    }

    /**
     * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent cTokens owned
     * E.g. User has 100 bUSDC, calls withdraw() and receives 100 USDC, burning the 100 bUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole cToken balance
     * @param to Address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     **/
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override nonReentrant whenNotPaused returns (uint256) {
        return
            SupplyLogic.executeWithdraw(
                _reserves,
                DataTypes.ExecuteWithdrawParams({
                    initiator: _msgSender(),
                    asset: asset,
                    amount: amount,
                    to: to
                })
            );
    }

    /**
     * @dev Allows users to borrow a specific `amount` of the reserve underlying asset
     * - E.g. User borrows 100 USDC, receiving the 100 USDC in his wallet
     *   and lock collateral asset in contract
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param nftAsset The address of the underlying nft used as collateral
     * @param nftTokenId The token ID of the underlying nft used as collateral
     * @param onBehalfOf Address of the user who will receive the loan. Should be the address of the borrower itself
     * calling the function if he wants to borrow against his own collateral
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     **/
    function borrow(
        address asset,
        uint256 amount,
        address nftAsset,
        uint256 nftTokenId,
        address onBehalfOf,
        uint16 referralCode
    ) external override nonReentrant whenNotPaused {
        BorrowLogic.executeBorrow(
            _addressesProvider,
            _reserves,
            _nfts,
            DataTypes.ExecuteBorrowParams({
                initiator: _msgSender(),
                asset: asset,
                amount: amount,
                nftAsset: nftAsset,
                nftTokenId: nftTokenId,
                onBehalfOf: onBehalfOf,
                referralCode: referralCode
            })
        );
    }

    function batchBorrow(
        address[] calldata assets,
        uint256[] calldata amounts,
        address[] calldata nftAssets,
        uint256[] calldata nftTokenIds,
        address onBehalfOf,
        uint16 referralCode
    ) external override nonReentrant whenNotPaused {
        DataTypes.ExecuteBatchBorrowParams memory params;
        params.initiator = _msgSender();
        params.assets = assets;
        params.amounts = amounts;
        params.nftAssets = nftAssets;
        params.nftTokenIds = nftTokenIds;
        params.onBehalfOf = onBehalfOf;
        params.referralCode = referralCode;

        BorrowLogic.executeBatchBorrow(
            _addressesProvider,
            _reserves,
            _nfts,
            params
        );
    }

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent loan owned
     * - E.g. User repays 100 USDC, burning loan and receives collateral asset
     * @param nftAsset The address of the underlying NFT used as collateral
     * @param nftTokenId The token ID of the underlying NFT used as collateral
     * @param amount The amount to repay
     **/
    function repay(
        address nftAsset,
        uint256 nftTokenId,
        uint256 amount
    ) external override nonReentrant whenNotPaused returns (uint256, bool) {
        return
            BorrowLogic.executeRepay(
                _addressesProvider,
                _reserves,
                _nfts,
                DataTypes.ExecuteRepayParams({
                    initiator: _msgSender(),
                    nftAsset: nftAsset,
                    nftTokenId: nftTokenId,
                    amount: amount
                })
            );
    }

    function batchRepay(
        address[] calldata nftAssets,
        uint256[] calldata nftTokenIds,
        uint256[] calldata amounts
    )
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256[] memory, bool[] memory)
    {
        return
            BorrowLogic.executeBatchRepay(
                _addressesProvider,
                _reserves,
                _nfts,
                DataTypes.ExecuteBatchRepayParams({
                    initiator: _msgSender(),
                    nftAssets: nftAssets,
                    nftTokenIds: nftTokenIds,
                    amounts: amounts
                })
            );
    }

    /**
     * @dev Function to execute buy-it-now on a non-healthy position collateral-wise
     * - The buy-it-now buyer wants to buy collateral asset of the user getting liquidated
     * @param nftAsset The address of the underlying NFT used as collateral
     * @param nftTokenId The token ID of the underlying NFT used as collateral
     * @param buyItNowPrice The buy-it-now price of the buy-it-now want to buy underlying NFT
     * @param onBehalfOf Address of the user who will get the underlying NFT, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of NFT
     *   is a different wallet
     **/
    function buyItNow(
        address nftAsset,
        uint256 nftTokenId,
        uint256 buyItNowPrice,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused {
        LiquidateLogic.executeBuyItNow(
            _addressesProvider,
            _reserves,
            _nfts,
            DataTypes.ExecuteBuyItNowParams({
                initiator: _msgSender(),
                nftAsset: nftAsset,
                nftTokenId: nftTokenId,
                buyItNowPrice: buyItNowPrice,
                onBehalfOf: onBehalfOf
            })
        );
    }

    /**
     * @notice Redeem a NFT loan which state is in BuyItNow
     * - E.g. User repays 100 USDC, burning loan and receives collateral asset
     * @param nftAsset The address of the underlying NFT used as collateral
     * @param nftTokenId The token ID of the underlying NFT used as collateral
     * @param amount The amount to repay the debt
     * @param buyItNowFine The amount of buy-it-now fine
     **/
    function redeem(
        address nftAsset,
        uint256 nftTokenId,
        uint256 amount,
        uint256 buyItNowFine
    ) external override nonReentrant whenNotPaused returns (uint256) {
        return
            LiquidateLogic.executeRedeem(
                _addressesProvider,
                _reserves,
                _nfts,
                DataTypes.ExecuteRedeemParams({
                    initiator: _msgSender(),
                    nftAsset: nftAsset,
                    nftTokenId: nftTokenId,
                    amount: amount,
                    buyItNowFine: buyItNowFine
                })
            );
    }

    /**
     * @dev Function to liquidate a non-healthy position collateral-wise
     * - The caller (liquidator) buy collateral asset of the user getting liquidated, and receives
     *   the collateral asset
     * @param nftAsset The address of the underlying NFT used as collateral
     * @param nftTokenId The token ID of the underlying NFT used as collateral
     **/
    function liquidate(
        address nftAsset,
        uint256 nftTokenId,
        uint256 amount
    ) external override nonReentrant whenNotPaused returns (uint256) {
        return
            LiquidateLogic.executeLiquidate(
                _addressesProvider,
                _reserves,
                _nfts,
                DataTypes.ExecuteLiquidateParams({
                    initiator: _msgSender(),
                    nftAsset: nftAsset,
                    nftTokenId: nftTokenId,
                    amount: amount
                })
            );
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        operator;
        from;
        tokenId;
        data;
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    /**
     * @dev Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     **/
    function getReserveConfiguration(address asset)
        external
        view
        override
        returns (DataTypes.ReserveConfigurationMap memory)
    {
        return _reserves[asset].configuration;
    }

    /**
     * @dev Returns the configuration of the NFT
     * @param asset The address of the asset of the NFT
     * @return The configuration of the NFT
     **/
    function getNftConfiguration(address asset)
        external
        view
        override
        returns (DataTypes.NftConfigurationMap memory)
    {
        return _nfts[asset].configuration;
    }

    /**
     * @dev Returns the normalized income normalized income of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(address asset)
        external
        view
        override
        returns (uint256)
    {
        return _reserves[asset].getNormalizedIncome();
    }

    /**
     * @dev Returns the normalized variable debt per unit of asset
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve normalized variable debt
     */
    function getReserveNormalizedVariableDebt(address asset)
        external
        view
        override
        returns (uint256)
    {
        return _reserves[asset].getNormalizedDebt();
    }

    /**
     * @dev Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        override
        returns (DataTypes.ReserveData memory)
    {
        return _reserves[asset];
    }

    /**
     * @dev Returns the state and configuration of the nft
     * @param asset The address of the underlying asset of the nft
     * @return The state of the nft
     **/
    function getNftData(address asset)
        external
        view
        override
        returns (DataTypes.NftData memory)
    {
        return _nfts[asset];
    }

    /**
     * @dev Returns the loan data of the NFT
     * @param nftAsset The address of the NFT
     * @param reserveAsset The address of the Reserve
     * @return totalCollateralInETH the total collateral in ETH of the NFT
     * @return totalCollateralInReserve the total collateral in Reserve of the NFT
     * @return availableBorrowsInETH the borrowing power in ETH of the NFT
     * @return availableBorrowsInReserve the borrowing power in Reserve of the NFT
     * @return ltv the loan to value of the user
     * @return liquidationThreshold the liquidation threshold of the NFT
     * @return liquidationBonus the liquidation bonus of the NFT
     **/
    function getNftCollateralData(address nftAsset, address reserveAsset)
        external
        view
        override
        returns (
            uint256 totalCollateralInETH,
            uint256 totalCollateralInReserve,
            uint256 availableBorrowsInETH,
            uint256 availableBorrowsInReserve,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus
        )
    {
        DataTypes.NftData storage nftData = _nfts[nftAsset];

        DataTypes.ReserveData storage reserveData = _reserves[reserveAsset];

        (ltv, liquidationThreshold, liquidationBonus) = nftData
            .configuration
            .getCollateralParams();

        (totalCollateralInETH, totalCollateralInReserve) = GenericLogic
            .calculateNftCollateralData(
                reserveAsset,
                reserveData,
                nftAsset,
                nftData,
                _addressesProvider.getReserveOracle(),
                _addressesProvider.getNFTOracle()
            );

        availableBorrowsInETH = GenericLogic.calculateAvailableBorrows(
            totalCollateralInETH,
            0,
            ltv
        );
        availableBorrowsInReserve = GenericLogic.calculateAvailableBorrows(
            totalCollateralInReserve,
            0,
            ltv
        );
    }

    /**
     * @dev Returns the debt data of the NFT
     * @param nftAsset The address of the NFT
     * @param nftTokenId The token id of the NFT
     * @return loanId the loan id of the NFT
     * @return reserveAsset the address of the Reserve
     * @return totalCollateral the total power of the NFT
     * @return totalDebt the total debt of the NFT
     * @return availableBorrows the borrowing power left of the NFT
     * @return healthFactor the current health factor of the NFT
     **/
    function getNftDebtData(address nftAsset, uint256 nftTokenId)
        external
        view
        override
        returns (
            uint256 loanId,
            address reserveAsset,
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 availableBorrows,
            uint256 healthFactor
        )
    {
        DataTypes.NftData storage nftData = _nfts[nftAsset];

        (uint256 ltv, uint256 liquidationThreshold, ) = nftData
            .configuration
            .getCollateralParams();

        loanId = ILendPoolLoan(_addressesProvider.getLendPoolLoan())
            .getCollateralLoanId(nftAsset, nftTokenId);
        if (loanId == 0) {
            return (0, address(0), 0, 0, 0, 0);
        }

        DataTypes.LoanData memory loan = ILendPoolLoan(
            _addressesProvider.getLendPoolLoan()
        ).getLoan(loanId);

        reserveAsset = loan.reserveAsset;
        DataTypes.ReserveData storage reserveData = _reserves[reserveAsset];

        (, totalCollateral) = GenericLogic.calculateNftCollateralData(
            reserveAsset,
            reserveData,
            nftAsset,
            nftData,
            _addressesProvider.getReserveOracle(),
            _addressesProvider.getNFTOracle()
        );

        (, totalDebt) = GenericLogic.calculateNftDebtData(
            reserveAsset,
            reserveData,
            _addressesProvider.getLendPoolLoan(),
            loanId,
            _addressesProvider.getReserveOracle()
        );

        availableBorrows = GenericLogic.calculateAvailableBorrows(
            totalCollateral,
            totalDebt,
            ltv
        );

        if (loan.state == DataTypes.LoanState.Active) {
            healthFactor = GenericLogic.calculateHealthFactorFromBalances(
                totalCollateral,
                totalDebt,
                liquidationThreshold
            );
        }
    }

    /**
     * @dev Returns the buy-it-now data of the NFT
     * @param nftAsset The address of the NFT
     * @param nftTokenId The token id of the NFT
     * @return loanId the loan id of the NFT
     * @return buyItNowBuyerAddress the buy-it-now buyer address of the loan
     * @return buyItNowPrice the highest buy-it-now price in Reserve of the loan
     * @return buyItNowBorrowAmount the borrow amount in Reserve of the loan
     * @return buyItNowFine the penalty fine of the loan
     **/
    function getNftBuyItNowData(address nftAsset, uint256 nftTokenId)
        external
        view
        override
        returns (
            uint256 loanId,
            address buyItNowBuyerAddress,
            uint256 buyItNowPrice,
            uint256 buyItNowBorrowAmount,
            uint256 buyItNowFine
        )
    {
        DataTypes.NftData storage nftData = _nfts[nftAsset];
        ILendPoolLoan poolLoan = ILendPoolLoan(
            _addressesProvider.getLendPoolLoan()
        );

        loanId = poolLoan.getCollateralLoanId(nftAsset, nftTokenId);
        if (loanId != 0) {
            DataTypes.LoanData memory loan = ILendPoolLoan(
                _addressesProvider.getLendPoolLoan()
            ).getLoan(loanId);
            DataTypes.ReserveData storage reserveData = _reserves[
                loan.reserveAsset
            ];

            buyItNowBuyerAddress = loan.buyItNowBuyerAddress;
            buyItNowPrice = loan.buyItNowPrice;
            buyItNowBorrowAmount = loan.buyItNowBorrowAmount;

            (, buyItNowFine) = GenericLogic.calculateLoanBuyItNowFine(
                loan.reserveAsset,
                reserveData,
                nftAsset,
                nftData,
                loan,
                address(poolLoan),
                _addressesProvider.getReserveOracle()
            );
        }
    }

    struct GetLiquidationPriceLocalVars {
        address poolLoan;
        uint256 loanId;
        uint256 thresholdPrice;
        uint256 liquidatePrice;
        uint256 paybackAmount;
        uint256 remainAmount;
    }

    function getNftLiquidatePrice(address nftAsset, uint256 nftTokenId)
        external
        view
        override
        returns (uint256 liquidatePrice, uint256 paybackAmount)
    {
        GetLiquidationPriceLocalVars memory vars;

        vars.poolLoan = _addressesProvider.getLendPoolLoan();
        vars.loanId = ILendPoolLoan(vars.poolLoan).getCollateralLoanId(
            nftAsset,
            nftTokenId
        );
        if (vars.loanId == 0) {
            return (0, 0);
        }

        DataTypes.LoanData memory loanData = ILendPoolLoan(vars.poolLoan)
            .getLoan(vars.loanId);

        DataTypes.ReserveData storage reserveData = _reserves[
            loanData.reserveAsset
        ];
        DataTypes.NftData storage nftData = _nfts[nftAsset];

        (
            vars.paybackAmount,
            vars.thresholdPrice,
            vars.liquidatePrice
        ) = GenericLogic.calculateLoanLiquidatePrice(
            vars.loanId,
            loanData.reserveAsset,
            reserveData,
            loanData.nftAsset,
            nftData,
            vars.poolLoan,
            _addressesProvider.getReserveOracle(),
            _addressesProvider.getNFTOracle()
        );

        if (vars.liquidatePrice < vars.paybackAmount) {
            vars.liquidatePrice = vars.paybackAmount;
        }

        return (vars.liquidatePrice, vars.paybackAmount);
    }

    /**
     * @dev Validates and finalizes an cToken transfer
     * - Only callable by the overlying cToken of the `asset`
     * @param asset The address of the underlying asset of the cToken
     * @param from The user from which the cToken are transferred
     * @param to The user receiving the cTokens
     * @param amount The amount being transferred/withdrawn
     * @param balanceFromBefore The cToken balance of the `from` user before the transfer
     * @param balanceToBefore The cToken balance of the `to` user before the transfer
     */
    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external view override whenNotPaused {
        asset;
        from;
        to;
        amount;
        balanceFromBefore;
        balanceToBefore;

        DataTypes.ReserveData storage reserve = _reserves[asset];
        require(
            _msgSender() == reserve.cTokenAddress,
            Errors.LP_CALLER_MUST_BE_AN_CTOKEN
        );

        ValidationLogic.validateTransfer(from, reserve);
    }

    /**
     * @dev Returns the list of the initialized reserves
     **/
    function getReservesList()
        external
        view
        override
        returns (address[] memory)
    {
        address[] memory _activeReserves = new address[](_reservesCount);

        for (uint256 i = 0; i < _reservesCount; i++) {
            _activeReserves[i] = _reservesList[i];
        }
        return _activeReserves;
    }

    /**
     * @dev Returns the list of the initialized nfts
     **/
    function getNftsList() external view override returns (address[] memory) {
        address[] memory _activeNfts = new address[](_nftsCount);

        for (uint256 i = 0; i < _nftsCount; i++) {
            _activeNfts[i] = _nftsList[i];
        }
        return _activeNfts;
    }

    /**
     * @dev Set the _pause state of the pool
     * - Only callable by the LendPoolConfigurator contract
     * @param val `true` to pause the pool, `false` to un-pause it
     */
    function setPause(bool val) external override onlyLendPoolConfigurator {
        _paused = val;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    /**
     * @dev Returns if the LendPool is paused
     */
    function paused() external view override returns (bool) {
        return _paused;
    }

    /**
     * @dev Returns the cached LendPoolAddressesProvider connected to this contract
     **/
    function getAddressesProvider()
        external
        view
        override
        returns (ILendPoolAddressesProvider)
    {
        return _addressesProvider;
    }

    function setMaxNumberOfReserves(uint256 val)
        external
        override
        onlyLendPoolConfigurator
    {
        _maxNumberOfReserves = val;
    }

    /**
     * @dev Returns the maximum number of reserves supported to be listed in this LendPool
     */
    function getMaxNumberOfReserves() public view override returns (uint256) {
        return _maxNumberOfReserves;
    }

    function setMaxNumberOfNfts(uint256 val)
        external
        override
        onlyLendPoolConfigurator
    {
        _maxNumberOfNfts = val;
    }

    /**
     * @dev Returns the maximum number of nfts supported to be listed in this LendPool
     */
    function getMaxNumberOfNfts() public view override returns (uint256) {
        return _maxNumberOfNfts;
    }

    /**
     * @dev Initializes a reserve, activating it, assigning an cToken and nft loan and an
     * interest rate strategy
     * - Only callable by the LendPoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param cTokenAddress The address of the cToken that will be assigned to the reserve
     * @param debtTokenAddress The address of the debtToken that will be assigned to the reserve
     * @param interestRateAddress The address of the interest rate strategy contract
     **/
    function initReserve(
        address asset,
        address cTokenAddress,
        address debtTokenAddress,
        address interestRateAddress
    ) external override onlyLendPoolConfigurator {
        require(AddressUpgradeable.isContract(asset), Errors.LP_NOT_CONTRACT);
        _reserves[asset].init(
            cTokenAddress,
            debtTokenAddress,
            interestRateAddress
        );
        _addReserveToList(asset);
    }

    /**
     * @dev Initializes a nft, activating it, assigning nft loan and an
     * interest rate strategy
     * - Only callable by the LendPoolConfigurator contract
     * @param asset The address of the underlying asset of the nft
     **/
    function initNft(address asset, address cNFTAddress)
        external
        override
        onlyLendPoolConfigurator
    {
        require(AddressUpgradeable.isContract(asset), Errors.LP_NOT_CONTRACT);
        _nfts[asset].init(cNFTAddress);
        _addNftToList(asset);

        require(
            _addressesProvider.getLendPoolLoan() != address(0),
            Errors.LPC_INVALIED_LOAN_ADDRESS
        );
        IERC721Upgradeable(asset).setApprovalForAll(
            _addressesProvider.getLendPoolLoan(),
            true
        );

        ILendPoolLoan(_addressesProvider.getLendPoolLoan()).initNft(
            asset,
            cNFTAddress
        );
    }

    /**
     * @dev Updates the address of the interest rate strategy contract
     * - Only callable by the LendPoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param rateAddress The address of the interest rate strategy contract
     **/
    function setReserveInterestRateAddress(address asset, address rateAddress)
        external
        override
        onlyLendPoolConfigurator
    {
        _reserves[asset].interestRateAddress = rateAddress;
    }

    /**
     * @dev Sets the configuration bitmap of the reserve as a whole
     * - Only callable by the LendPoolConfigurator contract
     * @param asset The address of the underlying asset of the reserve
     * @param configuration The new configuration bitmap
     **/
    function setReserveConfiguration(address asset, uint256 configuration)
        external
        override
        onlyLendPoolConfigurator
    {
        _reserves[asset].configuration.data = configuration;
    }

    /**
     * @dev Sets the configuration bitmap of the NFT as a whole
     * - Only callable by the LendPoolConfigurator contract
     * @param asset The address of the asset of the NFT
     * @param configuration The new configuration bitmap
     **/
    function setNftConfiguration(address asset, uint256 configuration)
        external
        override
        onlyLendPoolConfigurator
    {
        _nfts[asset].configuration.data = configuration;
    }

    function _addReserveToList(address asset) internal {
        uint256 reservesCount = _reservesCount;

        require(
            reservesCount < _maxNumberOfReserves,
            Errors.LP_NO_MORE_RESERVES_ALLOWED
        );

        bool reserveAlreadyAdded = _reserves[asset].id != 0 ||
            _reservesList[0] == asset;

        if (!reserveAlreadyAdded) {
            _reserves[asset].id = uint8(reservesCount);
            _reservesList[reservesCount] = asset;

            _reservesCount = reservesCount + 1;
        }
    }

    function _addNftToList(address asset) internal {
        uint256 nftsCount = _nftsCount;

        require(nftsCount < _maxNumberOfNfts, Errors.LP_NO_MORE_NFTS_ALLOWED);

        bool nftAlreadyAdded = _nfts[asset].id != 0 || _nftsList[0] == asset;

        if (!nftAlreadyAdded) {
            _nfts[asset].id = uint8(nftsCount);
            _nftsList[nftsCount] = asset;

            _nftsCount = nftsCount + 1;
        }
    }

    function _verifyCallResult(
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

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface ILendPoolLoan {
    /**
     * @dev Emitted on initialization to share location of dependent notes
     * @param pool The address of the associated lend pool
     */
    event Initialized(address indexed pool);

    /**
     * @dev Emitted when a loan is created
     * @param user The address initiating the action
     */
    event LoanCreated(
        address indexed user,
        address indexed onBehalfOf,
        uint256 indexed loanId,
        address nftAsset,
        uint256 nftTokenId,
        address reserveAsset,
        uint256 amount,
        uint256 borrowIndex
    );

    /**
     * @dev Emitted when a loan is updated
     * @param user The address initiating the action
     */
    event LoanUpdated(
        address indexed user,
        uint256 indexed loanId,
        address nftAsset,
        uint256 nftTokenId,
        address reserveAsset,
        uint256 amountAdded,
        uint256 amountTaken,
        uint256 borrowIndex
    );

    /**
     * @dev Emitted when a loan is repaid by the borrower
     * @param user The address initiating the action
     */
    event LoanRepaid(
        address indexed user,
        uint256 indexed loanId,
        address nftAsset,
        uint256 nftTokenId,
        address reserveAsset,
        uint256 amount,
        uint256 borrowIndex
    );

    /**
     * @dev Emitted when a loan is set to buy-it-now sale by the liquidator
     * @param user The address initiating the action
     */
    event LoanBought(
        address indexed user,
        uint256 indexed loanId,
        address nftAsset,
        uint256 nftTokenId,
        uint256 amount,
        uint256 borrowIndex,
        address buyItNowbuyer,
        uint256 price
    );

    /**
     * @dev Emitted when a loan is redeemed
     * @param user The address initiating the action
     */
    event LoanRedeemed(
        address indexed user,
        uint256 indexed loanId,
        address nftAsset,
        uint256 nftTokenId,
        address reserveAsset,
        uint256 amountTaken,
        uint256 borrowIndex
    );

    /**
     * @dev Emitted when a loan is liquidate by the liquidator
     * @param user The address initiating the action
     */
    event LoanLiquidated(
        address indexed user,
        uint256 indexed loanId,
        address nftAsset,
        uint256 nftTokenId,
        address reserveAsset,
        uint256 amount,
        uint256 borrowIndex
    );

    function initNft(address nftAsset, address cNFTAddress) external;

    /**
     * @dev Create store a loan object with some params
     * @param initiator The address of the user initiating the borrow
     * @param onBehalfOf The address receiving the loan
     */
    function createLoan(
        address initiator,
        address onBehalfOf,
        address nftAsset,
        uint256 nftTokenId,
        address cNFTAddress,
        address reserveAsset,
        uint256 amount,
        uint256 borrowIndex
    ) external returns (uint256);

    /**
     * @dev Update the given loan with some params
     *
     * Requirements:
     *  - The caller must be a holder of the loan
     *  - The loan must be in state Active
     * @param initiator The address of the user initiating the borrow
     */
    function updateLoan(
        address initiator,
        uint256 loanId,
        uint256 amountAdded,
        uint256 amountTaken,
        uint256 borrowIndex
    ) external;

    /**
     * @dev Repay the given loan
     *
     * Requirements:
     *  - The caller must be a holder of the loan
     *  - The caller must send in principal + interest
     *  - The loan must be in state Active
     *
     * @param initiator The address of the user initiating the repay
     * @param loanId The loan getting burned
     * @param cNFTAddress The address of cNFT
     */
    function repayLoan(
        address initiator,
        uint256 loanId,
        address cNFTAddress,
        uint256 amount,
        uint256 borrowIndex
    ) external;

    /**
     * @dev Set Loan to Buy-It-Now
     *
     * Requirements:
     *  - The price must be greater than current highest price
     *  - The loan must be in state Active or Buy-It-Now
     *
     * @param initiator The address of the user initiating the buy-it-now sale
     * @param loanId The loan getting set to buy-it-now
     * @param buyItNowPrice The buy-it-now price of this sale
     */
    function buyItNowLoan(
        address initiator,
        uint256 loanId,
        address onBehalfOf,
        uint256 buyItNowPrice,
        uint256 borrowAmount,
        uint256 borrowIndex
    ) external;

    /**
     * @dev Redeem the given loan with some params
     *
     * Requirements:
     *  - The caller must be a holder of the loan
     *  - The loan must be in state BuyItNow
     * @param initiator The address of the user initiating the borrow
     */
    function redeemLoan(
        address initiator,
        uint256 loanId,
        uint256 amountTaken,
        uint256 borrowIndex
    ) external;

    /**
     * @dev Liquidate the given loan
     *
     * Requirements:
     *  - The caller must send in principal + interest
     *  - The loan must be in state Active
     *
     * @param initiator The address of the user initiating the buy-it-now sale
     * @param loanId The loan getting burned
     * @param cNFTAddress The address of cNFT
     */
    function liquidateLoan(
        address initiator,
        uint256 loanId,
        address cNFTAddress,
        uint256 borrowAmount,
        uint256 borrowIndex
    ) external;

    function borrowerOf(uint256 loanId) external view returns (address);

    function getCollateralLoanId(address nftAsset, uint256 nftTokenId)
        external
        view
        returns (uint256);

    function getLoan(uint256 loanId)
        external
        view
        returns (DataTypes.LoanData memory loanData);

    function getLoanCollateralAndReserve(uint256 loanId)
        external
        view
        returns (
            address nftAsset,
            uint256 nftTokenId,
            address reserveAsset,
            uint256 scaledAmount
        );

    function getLoanReserveBorrowScaledAmount(uint256 loanId)
        external
        view
        returns (address, uint256);

    function getLoanReserveBorrowAmount(uint256 loanId)
        external
        view
        returns (address, uint256);

    function getLoanBuyItNowPrice(uint256 loanId)
        external
        view
        returns (address, uint256);

    function getNftCollateralAmount(address nftAsset)
        external
        view
        returns (uint256);

    function getUserNftCollateralAmount(address user, address nftAsset)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ILendPoolAddressesProvider} from "./ILendPoolAddressesProvider.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";

interface ILendPool {
  /**
   * @dev Emitted on deposit()
   * @param user The address initiating the deposit
   * @param amount The amount deposited
   * @param reserve The address of the underlying asset of the reserve
   * @param onBehalfOf The beneficiary of the deposit, receiving the cTokens
   * @param referral The referral code used
   **/
  event Deposit(
    address user,
    address indexed reserve,
    uint256 amount,
    address indexed onBehalfOf,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on withdraw()
   * @param user The address initiating the withdrawal, owner of cTokens
   * @param reserve The address of the underlyng asset being withdrawn
   * @param amount The amount to be withdrawn
   * @param to Address that will receive the underlying
   **/
  event Withdraw(address indexed user, address indexed reserve, uint256 amount, address indexed to);

  /**
   * @dev Emitted on borrow() when loan needs to be opened
   * @param user The address of the user initiating the borrow(), receiving the funds
   * @param reserve The address of the underlying asset being borrowed
   * @param amount The amount borrowed out
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token id of the underlying NFT used as collateral
   * @param onBehalfOf The address that will be getting the loan
   * @param referral The referral code used
   **/
  event Borrow(
    address user,
    address indexed reserve,
    uint256 amount,
    address nftAsset,
    uint256 nftTokenId,
    address indexed onBehalfOf,
    uint256 borrowRate,
    uint256 loanId,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on repay()
   * @param user The address of the user initiating the repay(), providing the funds
   * @param reserve The address of the underlying asset of the reserve
   * @param amount The amount repaid
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token id of the underlying NFT used as collateral
   * @param borrower The beneficiary of the repayment, getting his debt reduced
   * @param loanId The loan ID of the NFT loans
   **/
  event Repay(
    address user,
    address indexed reserve,
    uint256 amount,
    address indexed nftAsset,
    uint256 nftTokenId,
    address indexed borrower,
    uint256 loanId
  );

  /**
   * @dev Emitted when a borrower's loan is placed for Buy It Now Sale.
   * @param user The address of the user initiating the Buy It Now Sale
   * @param reserve The address of the underlying asset of the reserve
   * @param buyItNowPrice The price of the underlying reserve placed for sale
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token id of the underlying NFT used as collateral
   * @param onBehalfOf The address that will be getting the NFT
   * @param loanId The loan ID of the NFT loans
   **/
  event BuyItNow(
    address user,
    address indexed reserve,
    uint256 buyItNowPrice,
    address indexed nftAsset,
    uint256 nftTokenId,
    address onBehalfOf,
    address indexed borrower,
    uint256 loanId
  );

  /**
   * @dev Emitted on redeem()
   * @param user The address of the user initiating the redeem(), providing the funds
   * @param reserve The address of the underlying asset of the reserve
   * @param borrowAmount The borrow amount repaid
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token id of the underlying NFT used as collateral
   * @param loanId The loan ID of the NFT loans
   **/
  event Redeem(
    address user,
    address indexed reserve,
    uint256 borrowAmount,
    uint256 fineAmount,
    address indexed nftAsset,
    uint256 nftTokenId,
    address indexed borrower,
    uint256 loanId
  );

  /**
   * @dev Emitted when a borrower's loan is liquidated.
   * @param user The address of the user initiating the buy-it-now sale
   * @param reserve The address of the underlying asset of the reserve
   * @param repayAmount The amount of reserve repaid by the liquidator
   * @param remainAmount The amount of reserve received by the borrower
   * @param loanId The loan ID of the NFT loans
   **/
  event Liquidate(
    address user,
    address indexed reserve,
    uint256 repayAmount,
    uint256 remainAmount,
    address indexed nftAsset,
    uint256 nftTokenId,
    address indexed borrower,
    uint256 loanId
  );

  /**
   * @dev Emitted when the pause is triggered.
   */
  event Paused();

  /**
   * @dev Emitted when the pause is lifted.
   */
  event Unpaused();

  /**
   * @dev Emitted when the state of a reserve is updated. NOTE: This event is actually declared
   * in the ReserveLogic library and emitted in the updateInterestRates() function. Since the function is internal,
   * the event will actually be fired by the LendPool contract. The event is therefore replicated here so it
   * gets added to the LendPool ABI
   * @param reserve The address of the underlying asset of the reserve
   * @param liquidityRate The new liquidity rate
   * @param variableBorrowRate The new variable borrow rate
   * @param liquidityIndex The new liquidity index
   * @param variableBorrowIndex The new variable borrow index
   **/
  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying cTokens.
   * - E.g. User deposits 100 USDC and gets in return 100 bUSDC
   * @param reserve The address of the underlying asset to deposit
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the cTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of cTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function deposit(
    address reserve,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent cTokens owned
   * E.g. User has 100 bUSDC, calls withdraw() and receives 100 USDC, burning the 100 bUSDC
   * @param reserve The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole cToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   **/
  function withdraw(
    address reserve,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @dev Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
   * already deposited enough collateral
   * - E.g. User borrows 100 USDC, receiving the 100 USDC in his wallet
   *   and lock collateral asset in contract
   * @param reserveAsset The address of the underlying asset to borrow
   * @param amount The amount to be borrowed
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token ID of the underlying NFT used as collateral
   * @param onBehalfOf Address of the user who will receive the loan. Should be the address of the borrower itself
   * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
   * if he has been given credit delegation allowance
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function borrow(
    address reserveAsset,
    uint256 amount,
    address nftAsset,
    uint256 nftTokenId,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  function batchBorrow(
    address[] calldata assets,
    uint256[] calldata amounts,
    address[] calldata nftAssets,
    uint256[] calldata nftTokenIds,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent loan owned
   * - E.g. User repays 100 USDC, burning loan and receives collateral asset
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token ID of the underlying NFT used as collateral
   * @param amount The amount to repay
   * @return The final amount repaid, loan is burned or not
   **/
  function repay(
    address nftAsset,
    uint256 nftTokenId,
    uint256 amount
  ) external returns (uint256, bool);

  function batchRepay(
    address[] calldata nftAssets,
    uint256[] calldata nftTokenIds,
    uint256[] calldata amounts
  ) external returns (uint256[] memory, bool[] memory);

  /**
   * @notice Redeem a NFT loan which state is in BuyItNow
   * @dev Function to start buy-it-now sale a non-healthy position collateral-wise
   * - The caller (liquidator) want to buy collateral asset of the user getting liquidated
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token ID of the underlying NFT used as collateral
   * @param buyItNowPrice The buy it now price of the liquidator want to buy the underlying NFT
   * @param onBehalfOf Address of the user who will get the underlying NFT, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of NFT
   *   is a different wallet
   **/
  function buyItNow(
    address nftAsset,
    uint256 nftTokenId,
    uint256 buyItNowPrice,
    address onBehalfOf
  ) external;

  /**
   * @notice Redeem a NFT loan which state is in Buy It Now Sale
   * - E.g. User repays 100 USDC, burning loan and receives collateral asset
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token ID of the underlying NFT used as collateral
   * @param amount The amount to repay the debt
   * @param buyItNowFine The amount of buy it now fine
   **/
  function redeem(
    address nftAsset,
    uint256 nftTokenId,
    uint256 amount,
    uint256 buyItNowFine
  ) external returns (uint256);

  /**
   * @dev Function to liquidate a non-healthy position collateral-wise
   * - The caller (liquidator) buy collateral asset of the user getting liquidated, and receives
   *   the collateral asset
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token ID of the underlying NFT used as collateral
   **/
  function liquidate(
    address nftAsset,
    uint256 nftTokenId,
    uint256 amount
  ) external returns (uint256);

  /**
   * @dev Validates and finalizes an cToken transfer
   * - Only callable by the overlying cToken of the `asset`
   * @param asset The address of the underlying asset of the cToken
   * @param from The user from which the cTokens are transferred
   * @param to The user receiving the cTokens
   * @param amount The amount being transferred/withdrawn
   * @param balanceFromBefore The cToken balance of the `from` user before the transfer
   * @param balanceToBefore The cToken balance of the `to` user before the transfer
   */
  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromBefore,
    uint256 balanceToBefore
  ) external view;

  function getReserveConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory);

  function getNftConfiguration(address asset) external view returns (DataTypes.NftConfigurationMap memory);

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  /**
   * @dev Returns the normalized variable debt per unit of asset
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  /**
   * @dev Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state of the reserve
   **/
  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

  function getReservesList() external view returns (address[] memory);

  function getNftData(address asset) external view returns (DataTypes.NftData memory);

  /**
   * @dev Returns the loan data of the NFT
   * @param nftAsset The address of the NFT
   * @param reserveAsset The address of the Reserve
   * @return totalCollateralInETH the total collateral in ETH of the NFT
   * @return totalCollateralInReserve the total collateral in Reserve of the NFT
   * @return availableBorrowsInETH the borrowing power in ETH of the NFT
   * @return availableBorrowsInReserve the borrowing power in Reserve of the NFT
   * @return ltv the loan to value of the user
   * @return liquidationThreshold the liquidation threshold of the NFT
   * @return liquidationBonus the liquidation bonus of the NFT
   **/
  function getNftCollateralData(address nftAsset, address reserveAsset)
    external
    view
    returns (
      uint256 totalCollateralInETH,
      uint256 totalCollateralInReserve,
      uint256 availableBorrowsInETH,
      uint256 availableBorrowsInReserve,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus
    );

  /**
   * @dev Returns the debt data of the NFT
   * @param nftAsset The address of the NFT
   * @param nftTokenId The token id of the NFT
   * @return loanId the loan id of the NFT
   * @return reserveAsset the address of the Reserve
   * @return totalCollateral the total power of the NFT
   * @return totalDebt the total debt of the NFT
   * @return availableBorrows the borrowing power left of the NFT
   * @return healthFactor the current health factor of the NFT
   **/
  function getNftDebtData(address nftAsset, uint256 nftTokenId)
    external
    view
    returns (
      uint256 loanId,
      address reserveAsset,
      uint256 totalCollateral,
      uint256 totalDebt,
      uint256 availableBorrows,
      uint256 healthFactor
    );

  /**
   * @dev Returns the buy-it-now sale data of the NFT
   * @param nftAsset The address of the NFT
   * @param nftTokenId The token id of the NFT
   * @return loanId the loan id of the NFT
   * @return buyItNowBuyerAddress the buy-it-now user address
   * @return buyItNowPrice the price in Reserve of the loan
   * @return buyItNowBorrowAmount the borrow amount in Reserve of the loan
   * @return buyItNowFine the penalty fine of the loan
   **/
  function getNftBuyItNowData(address nftAsset, uint256 nftTokenId)
    external
    view
    returns (
      uint256 loanId,
      address buyItNowBuyerAddress,
      uint256 buyItNowPrice,
      uint256 buyItNowBorrowAmount,
      uint256 buyItNowFine
    );

  function getNftLiquidatePrice(address nftAsset, uint256 nftTokenId)
    external
    view
    returns (uint256 liquidatePrice, uint256 paybackAmount);

  function getNftsList() external view returns (address[] memory);

  /**
   * @dev Set the _pause state of a reserve
   * - Only callable by the LendPool contract
   * @param val `true` to pause the reserve, `false` to un-pause it
   */
  function setPause(bool val) external;

  /**
   * @dev Returns if the LendPool is paused
   */
  function paused() external view returns (bool);

  function getAddressesProvider() external view returns (ILendPoolAddressesProvider);

  function initReserve(
    address asset,
    address cTokenAddress,
    address debtTokenAddress,
    address interestRateAddress
  ) external;

  function initNft(address asset, address cNFTAddress) external;

  function setReserveInterestRateAddress(address asset, address rateAddress) external;

  function setReserveConfiguration(address asset, uint256 configuration) external;

  function setNftConfiguration(address asset, uint256 configuration) external;

  function setMaxNumberOfReserves(uint256 val) external;

  function setMaxNumberOfNfts(uint256 val) external;

  function getMaxNumberOfReserves() external view returns (uint256);

  function getMaxNumberOfNfts() external view returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

/**
 * @title LendPoolAddressesProvider contract
 * @dev Main registry of addresses part of or connected to the protocol, including permissioned roles
 * - Acting also as factory of proxies and admin of those, so with right to change its implementations
 * - Owned by the Confetti Governance
 * @author Confetti
 **/
interface ILendPoolAddressesProvider {
  event MarketIdSet(string newMarketId);
  event LendPoolUpdated(address indexed newAddress, bytes encodedCallData);
  event ConfigurationAdminUpdated(address indexed newAddress);
  event EmergencyAdminUpdated(address indexed newAddress);
  event LendPoolConfiguratorUpdated(address indexed newAddress, bytes encodedCallData);
  event ReserveOracleUpdated(address indexed newAddress);
  event NftOracleUpdated(address indexed newAddress);
  event LendPoolLoanUpdated(address indexed newAddress, bytes encodedCallData);
  event ProxyCreated(bytes32 id, address indexed newAddress);
  event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy, bytes encodedCallData);
  event CNFTRegistryUpdated(address indexed newAddress);
  event IncentivesControllerUpdated(address indexed newAddress);
  event UIDataProviderUpdated(address indexed newAddress);
  event ConfettiDataProviderUpdated(address indexed newAddress);
  event WalletBalanceProviderUpdated(address indexed newAddress);

  function getMarketId() external view returns (string memory);

  function setMarketId(string calldata marketId) external;

  function setAddress(bytes32 id, address newAddress) external;

  function setAddressAsProxy(
    bytes32 id,
    address impl,
    bytes memory encodedCallData
  ) external;

  function getAddress(bytes32 id) external view returns (address);

  function getLendPool() external view returns (address);

  function setLendPoolImpl(address pool, bytes memory encodedCallData) external;

  function getLendPoolConfigurator() external view returns (address);

  function setLendPoolConfiguratorImpl(address configurator, bytes memory encodedCallData) external;

  function getPoolAdmin() external view returns (address);

  function setPoolAdmin(address admin) external;

  function getEmergencyAdmin() external view returns (address);

  function setEmergencyAdmin(address admin) external;

  function getReserveOracle() external view returns (address);

  function setReserveOracle(address reserveOracle) external;

  function getNFTOracle() external view returns (address);

  function setNFTOracle(address nftOracle) external;

  function getLendPoolLoan() external view returns (address);

  function setLendPoolLoanImpl(address loan, bytes memory encodedCallData) external;

  function getCNFTRegistry() external view returns (address);

  function setCNFTRegistry(address factory) external;

  function getIncentivesController() external view returns (address);

  function setIncentivesController(address controller) external;

  function getUIDataProvider() external view returns (address);

  function setUIDataProvider(address provider) external;

  function getConfettiDataProvider() external view returns (address);

  function setConfettiDataProvider(address provider) external;

  function getWalletBalanceProvider() external view returns (address);

  function setWalletBalanceProvider(address provider) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

/**
 * @title Errors library
 * @author Confetti
 * @notice Defines the error messages emitted by the different contracts of the Confetti protocol
 */
library Errors {
    enum ReturnCode {
        SUCCESS,
        FAILED
    }

    string public constant SUCCESS = "0";

    //common errors
    string public constant CALLER_NOT_POOL_ADMIN = "100"; // 'The caller must be the pool admin'
    string public constant CALLER_NOT_ADDRESS_PROVIDER = "101";
    string public constant INVALID_FROM_BALANCE_AFTER_TRANSFER = "102";
    string public constant INVALID_TO_BALANCE_AFTER_TRANSFER = "103";
    string public constant CALLER_NOT_ONBEHALFOF_OR_IN_WHITELIST = "104";

    //math library erros
    string public constant MATH_MULTIPLICATION_OVERFLOW = "200";
    string public constant MATH_ADDITION_OVERFLOW = "201";
    string public constant MATH_DIVISION_BY_ZERO = "202";

    //validation & check errors
    string public constant VL_INVALID_AMOUNT = "301"; // 'Amount must be greater than 0'
    string public constant VL_NO_ACTIVE_RESERVE = "302"; // 'Action requires an active reserve'
    string public constant VL_RESERVE_FROZEN = "303"; // 'Action cannot be performed because the reserve is frozen'
    string public constant VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE = "304"; // 'User cannot withdraw more than the available balance'
    string public constant VL_BORROWING_NOT_ENABLED = "305"; // 'Borrowing is not enabled'
    string public constant VL_COLLATERAL_BALANCE_IS_0 = "306"; // 'The collateral balance is 0'
    string public constant VL_HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD =
        "307"; // 'Health factor is lesser than the liquidation threshold'
    string public constant VL_COLLATERAL_CANNOT_COVER_NEW_BORROW = "308"; // 'There is not enough collateral to cover a new borrow'
    string public constant VL_NO_DEBT_OF_SELECTED_TYPE = "309"; // 'for repayment of stable debt, the user needs to have stable debt, otherwise, he needs to have variable debt'
    string public constant VL_NO_ACTIVE_NFT = "310";
    string public constant VL_NFT_FROZEN = "311";
    string public constant VL_SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER = "312"; // 'User did not borrow the specified currency'
    string public constant VL_INVALID_HEALTH_FACTOR = "313";
    string public constant VL_INVALID_ONBEHALFOF_ADDRESS = "314";
    string public constant VL_INVALID_TARGET_ADDRESS = "315";
    string public constant VL_INVALID_RESERVE_ADDRESS = "316";
    string public constant VL_SPECIFIED_LOAN_NOT_BORROWED_BY_USER = "317";
    string public constant VL_SPECIFIED_RESERVE_NOT_BORROWED_BY_USER = "318";
    string public constant VL_HEALTH_FACTOR_HIGHER_THAN_LIQUIDATION_THRESHOLD =
        "319";

    //lend pool errors
    string public constant LP_CALLER_NOT_LEND_POOL_CONFIGURATOR = "400"; // 'The caller of the function is not the lending pool configurator'
    string public constant LP_IS_PAUSED = "401"; // 'Pool is paused'
    string public constant LP_NO_MORE_RESERVES_ALLOWED = "402";
    string public constant LP_NOT_CONTRACT = "403";
    string public constant LP_BORROW_NOT_EXCEED_LIQUIDATION_THRESHOLD = "404";
    string public constant LP_BORROW_IS_EXCEED_LIQUIDATION_PRICE = "405";
    string public constant LP_NO_MORE_NFTS_ALLOWED = "406";
    string public constant LP_INVALIED_USER_NFT_AMOUNT = "407";
    string public constant LP_INCONSISTENT_PARAMS = "408";
    string public constant LP_NFT_IS_NOT_USED_AS_COLLATERAL = "409";
    string public constant LP_CALLER_MUST_BE_AN_CTOKEN = "410";
    string public constant LP_INVALIED_NFT_AMOUNT = "411";
    string public constant LP_NFT_HAS_USED_AS_COLLATERAL = "412";
    string public constant LP_DELEGATE_CALL_FAILED = "413";
    string public constant LP_AMOUNT_LESS_THAN_EXTRA_DEBT = "414";
    string public constant LP_AMOUNT_LESS_THAN_REDEEM_THRESHOLD = "415";
    string public constant LP_AMOUNT_GREATER_THAN_MAX_REPAY = "416";

    //lend pool loan errors
    string public constant LPL_INVALID_LOAN_STATE = "480";
    string public constant LPL_INVALID_LOAN_AMOUNT = "481";
    string public constant LPL_INVALID_TAKEN_AMOUNT = "482";
    string public constant LPL_AMOUNT_OVERFLOW = "483";
    string public constant LPL_BUYITNOW_PRICE_LESS_THAN_LIQUIDATION_PRICE =
        "484";
    string public constant LPL_BUYITNOW_PRICE_LESS_THAN_HIGHEST_PRICE = "485";
    string public constant LPL_BUYITNOW_REDEEM_DURATION_HAS_END = "486";
    string public constant LPL_BUYITNOW_BUYER_NOT_SAME = "487";
    string public constant LPL_BUYITNOW_REPAY_AMOUNT_NOT_ENOUGH = "488";
    string public constant LPL_BUYITNOW_DURATION_HAS_END = "489";
    string public constant LPL_BUYITNOW_DURATION_NOT_END = "490";
    string public constant LPL_BUYITNOW_PRICE_LESS_THAN_BORROW = "491";
    string public constant LPL_INVALID_BUYITNOW_BUYER_ADDRESS = "492";
    string public constant LPL_AMOUNT_LESS_THAN_BUYITNOW_FINE = "493";
    string public constant LPL_INVALID_BUYITNOW_FINE = "494";
    string public constant LPL_BUYITNOW_DURATION_NOT_START = "495";

    //common token errors
    string public constant CT_CALLER_MUST_BE_LEND_POOL = "500"; // 'The caller of this function must be a lending pool'
    string public constant CT_INVALID_MINT_AMOUNT = "501"; //invalid amount to mint
    string public constant CT_INVALID_BURN_AMOUNT = "502"; //invalid amount to burn
    string public constant CT_BORROW_ALLOWANCE_NOT_ENOUGH = "503";

    //reserve logic errors
    string public constant RL_RESERVE_ALREADY_INITIALIZED = "601"; // 'Reserve has already been initialized'
    string public constant RL_LIQUIDITY_INDEX_OVERFLOW = "602"; //  Liquidity index overflows uint128
    string public constant RL_VARIABLE_BORROW_INDEX_OVERFLOW = "603"; //  Variable borrow index overflows uint128
    string public constant RL_LIQUIDITY_RATE_OVERFLOW = "604"; //  Liquidity rate overflows uint128
    string public constant RL_VARIABLE_BORROW_RATE_OVERFLOW = "605"; //  Variable borrow rate overflows uint128

    //configure errors
    string public constant LPC_RESERVE_LIQUIDITY_NOT_0 = "700"; // 'The liquidity of the reserve needs to be 0'
    string public constant LPC_INVALID_CONFIGURATION = "701"; // 'Invalid risk parameters for the reserve'
    string public constant LPC_CALLER_NOT_EMERGENCY_ADMIN = "702"; // 'The caller must be the emergency admin'
    string public constant LPC_INVALIED_CNFT_ADDRESS = "703";
    string public constant LPC_INVALIED_LOAN_ADDRESS = "704";
    string public constant LPC_NFT_LIQUIDITY_NOT_0 = "705";

    //reserve config errors
    string public constant RC_INVALID_LTV = "730";
    string public constant RC_INVALID_LIQ_THRESHOLD = "731";
    string public constant RC_INVALID_LIQ_BONUS = "732";
    string public constant RC_INVALID_DECIMALS = "733";
    string public constant RC_INVALID_RESERVE_FACTOR = "734";
    string public constant RC_INVALID_REDEEM_DURATION = "735";
    string public constant RC_INVALID_BUYITNOW_DURATION = "736";
    string public constant RC_INVALID_REDEEM_FINE = "737";
    string public constant RC_INVALID_REDEEM_THRESHOLD = "738";
    string public constant RC_INVALID_MIN_BUYITNOW_FINE = "739";
    string public constant RC_INVALID_MAX_BUYITNOW_FINE = "740";

    //address provider erros
    string public constant LPAPR_PROVIDER_NOT_REGISTERED = "760"; // 'Provider is not registered'
    string public constant LPAPR_INVALID_ADDRESSES_PROVIDER_ID = "761";
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {Errors} from "../helpers/Errors.sol";

/**
 * @title WadRayMath library
 * @author Confetti
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)
 **/

library WadRayMath {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant HALF_WAD = WAD / 2;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant HALF_RAY = RAY / 2;

  uint256 internal constant WAD_RAY_RATIO = 1e9;

  /**
   * @return One ray, 1e27
   **/
  function ray() internal pure returns (uint256) {
    return RAY;
  }

  /**
   * @return One wad, 1e18
   **/

  function wad() internal pure returns (uint256) {
    return WAD;
  }

  /**
   * @return Half ray, 1e27/2
   **/
  function halfRay() internal pure returns (uint256) {
    return HALF_RAY;
  }

  /**
   * @return Half ray, 1e18/2
   **/
  function halfWad() internal pure returns (uint256) {
    return HALF_WAD;
  }

  /**
   * @dev Multiplies two wad, rounding half up to the nearest wad
   * @param a Wad
   * @param b Wad
   * @return The result of a*b, in wad
   **/
  function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }

    require(a <= (type(uint256).max - HALF_WAD) / b, Errors.MATH_MULTIPLICATION_OVERFLOW);

    return (a * b + HALF_WAD) / WAD;
  }

  /**
   * @dev Divides two wad, rounding half up to the nearest wad
   * @param a Wad
   * @param b Wad
   * @return The result of a/b, in wad
   **/
  function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, Errors.MATH_DIVISION_BY_ZERO);
    uint256 halfB = b / 2;

    require(a <= (type(uint256).max - halfB) / WAD, Errors.MATH_MULTIPLICATION_OVERFLOW);

    return (a * WAD + halfB) / b;
  }

  /**
   * @dev Multiplies two ray, rounding half up to the nearest ray
   * @param a Ray
   * @param b Ray
   * @return The result of a*b, in ray
   **/
  function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }

    require(a <= (type(uint256).max - HALF_RAY) / b, Errors.MATH_MULTIPLICATION_OVERFLOW);

    return (a * b + HALF_RAY) / RAY;
  }

  /**
   * @dev Divides two ray, rounding half up to the nearest ray
   * @param a Ray
   * @param b Ray
   * @return The result of a/b, in ray
   **/
  function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, Errors.MATH_DIVISION_BY_ZERO);
    uint256 halfB = b / 2;

    require(a <= (type(uint256).max - halfB) / RAY, Errors.MATH_MULTIPLICATION_OVERFLOW);

    return (a * RAY + halfB) / b;
  }

  /**
   * @dev Casts ray down to wad
   * @param a Ray
   * @return a casted to wad, rounded half up to the nearest wad
   **/
  function rayToWad(uint256 a) internal pure returns (uint256) {
    uint256 halfRatio = WAD_RAY_RATIO / 2;
    uint256 result = halfRatio + a;
    require(result >= halfRatio, Errors.MATH_ADDITION_OVERFLOW);

    return result / WAD_RAY_RATIO;
  }

  /**
   * @dev Converts wad up to ray
   * @param a Wad
   * @return a converted in ray
   **/
  function wadToRay(uint256 a) internal pure returns (uint256) {
    uint256 result = a * WAD_RAY_RATIO;
    require(result / WAD_RAY_RATIO == a, Errors.MATH_MULTIPLICATION_OVERFLOW);
    return result;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ILendPoolLoan} from "../../interfaces/ILendPoolLoan.sol";
import {IReserveOracleGetter} from "../../interfaces/IReserveOracleGetter.sol";
import {INFTOracleGetter} from "../../interfaces/INFTOracleGetter.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {NftConfiguration} from "../configuration/NftConfiguration.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "./ReserveLogic.sol";

/**
 * @title GenericLogic library
 * @author Confetti
 * @notice Implements protocol-level logic to calculate and validate the state of a user
 */
library GenericLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using NftConfiguration for DataTypes.NftConfigurationMap;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;

    struct CalculateLoanDataVars {
        uint256 reserveUnitPrice;
        uint256 reserveUnit;
        uint256 reserveDecimals;
        uint256 healthFactor;
        uint256 totalCollateralInETH;
        uint256 totalCollateralInReserve;
        uint256 totalDebtInETH;
        uint256 totalDebtInReserve;
        uint256 nftLtv;
        uint256 nftLiquidationThreshold;
        address nftAsset;
        uint256 nftTokenId;
        uint256 nftUnitPrice;
    }

    /**
     * @dev Calculates the nft loan data.
     * this includes the total collateral/borrow balances in Reserve,
     * the Loan To Value, the Liquidation Ratio, and the Health factor.
     * @param reserveData Data of the reserve
     * @param nftData Data of the nft
     * @param reserveOracle The price oracle address of reserve
     * @param nftOracle The price oracle address of nft
     * @return The total collateral and total debt of the loan in Reserve, the ltv, liquidation threshold and the HF
     **/
    function calculateLoanData(
        address reserveAddress,
        DataTypes.ReserveData storage reserveData,
        address nftAddress,
        DataTypes.NftData storage nftData,
        address loanAddress,
        uint256 loanId,
        address reserveOracle,
        address nftOracle
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        CalculateLoanDataVars memory vars;

        (vars.nftLtv, vars.nftLiquidationThreshold, ) = nftData
            .configuration
            .getCollateralParams();

        // calculate total borrow balance for the loan
        if (loanId != 0) {
            (
                vars.totalDebtInETH,
                vars.totalDebtInReserve
            ) = calculateNftDebtData(
                reserveAddress,
                reserveData,
                loanAddress,
                loanId,
                reserveOracle
            );
        }

        // calculate total collateral balance for the nft
        (
            vars.totalCollateralInETH,
            vars.totalCollateralInReserve
        ) = calculateNftCollateralData(
            reserveAddress,
            reserveData,
            nftAddress,
            nftData,
            reserveOracle,
            nftOracle
        );

        // calculate health by borrow and collateral
        vars.healthFactor = calculateHealthFactorFromBalances(
            vars.totalCollateralInReserve,
            vars.totalDebtInReserve,
            vars.nftLiquidationThreshold
        );

        return (
            vars.totalCollateralInReserve,
            vars.totalDebtInReserve,
            vars.healthFactor
        );
    }

    function calculateNftDebtData(
        address reserveAddress,
        DataTypes.ReserveData storage reserveData,
        address loanAddress,
        uint256 loanId,
        address reserveOracle
    ) internal view returns (uint256, uint256) {
        CalculateLoanDataVars memory vars;

        // all asset price has converted to ETH based, unit is in WEI (18 decimals)

        vars.reserveDecimals = reserveData.configuration.getDecimals();
        vars.reserveUnit = 10**vars.reserveDecimals;

        vars.reserveUnitPrice = IReserveOracleGetter(reserveOracle)
            .getAssetPrice(reserveAddress);

        (, vars.totalDebtInReserve) = ILendPoolLoan(loanAddress)
            .getLoanReserveBorrowAmount(loanId);
        vars.totalDebtInETH =
            (vars.totalDebtInReserve * vars.reserveUnitPrice) /
            vars.reserveUnit;

        return (vars.totalDebtInETH, vars.totalDebtInReserve);
    }

    function calculateNftCollateralData(
        address reserveAddress,
        DataTypes.ReserveData storage reserveData,
        address nftAddress,
        DataTypes.NftData storage nftData,
        address reserveOracle,
        address nftOracle
    ) internal view returns (uint256, uint256) {
        reserveData;
        nftData;

        CalculateLoanDataVars memory vars;

        // calculate total collateral balance for the nft
        // all asset price has converted to ETH based, unit is in WEI (18 decimals)

        vars.nftUnitPrice = INFTOracleGetter(nftOracle).getAssetPrice(
            nftAddress
        );
        vars.totalCollateralInETH = vars.nftUnitPrice;

        if (reserveAddress != address(0)) {
            vars.reserveDecimals = reserveData.configuration.getDecimals();
            vars.reserveUnit = 10**vars.reserveDecimals;

            vars.reserveUnitPrice = IReserveOracleGetter(reserveOracle)
                .getAssetPrice(reserveAddress);

            vars.totalCollateralInReserve =
                (vars.totalCollateralInETH * vars.reserveUnit) /
                vars.reserveUnitPrice;
        }

        return (vars.totalCollateralInETH, vars.totalCollateralInReserve);
    }

    /**
     * @dev Calculates the health factor from the corresponding balances
     * @param totalCollateral The total collateral
     * @param totalDebt The total debt
     * @param liquidationThreshold The avg liquidation threshold
     * @return The health factor calculated from the balances provided
     **/
    function calculateHealthFactorFromBalances(
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 liquidationThreshold
    ) internal pure returns (uint256) {
        if (totalDebt == 0) return type(uint256).max;

        return
            (totalCollateral.percentMul(liquidationThreshold)).wadDiv(
                totalDebt
            );
    }

    /**
     * @dev Calculates the equivalent amount that an user can borrow, depending on the available collateral and the
     * average Loan To Value
     * @param totalCollateral The total collateral
     * @param totalDebt The total borrow balance
     * @param ltv The average loan to value
     * @return the amount available to borrow for the user
     **/

    function calculateAvailableBorrows(
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 ltv
    ) internal pure returns (uint256) {
        uint256 availableBorrows = totalCollateral.percentMul(ltv);

        if (availableBorrows < totalDebt) {
            return 0;
        }

        availableBorrows = availableBorrows - totalDebt;
        return availableBorrows;
    }

    struct CalcLiquidatePriceLocalVars {
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 nftPriceInETH;
        uint256 nftPriceInReserve;
        uint256 reserveDecimals;
        uint256 reservePriceInETH;
        uint256 thresholdPrice;
        uint256 liquidatePrice;
        uint256 borrowAmount;
    }

    function calculateLoanLiquidatePrice(
        uint256 loanId,
        address reserveAsset,
        DataTypes.ReserveData storage reserveData,
        address nftAsset,
        DataTypes.NftData storage nftData,
        address poolLoan,
        address reserveOracle,
        address nftOracle
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        CalcLiquidatePriceLocalVars memory vars;

        /*
         * 0                   CR                  LH                  100
         * |___________________|___________________|___________________|
         *  <       Borrowing with Interest        <
         * CR: Callteral Ratio;
         * LH: Liquidate Threshold;
         * Liquidate Trigger: Borrowing with Interest > thresholdPrice;
         * Liquidate Price: (100% - BonusRatio) * NFT Price;
         */

        vars.reserveDecimals = reserveData.configuration.getDecimals();

        (, vars.borrowAmount) = ILendPoolLoan(poolLoan)
            .getLoanReserveBorrowAmount(loanId);

        (vars.ltv, vars.liquidationThreshold, vars.liquidationBonus) = nftData
            .configuration
            .getCollateralParams();

        vars.nftPriceInETH = INFTOracleGetter(nftOracle).getAssetPrice(
            nftAsset
        );
        vars.reservePriceInETH = IReserveOracleGetter(reserveOracle)
            .getAssetPrice(reserveAsset);

        vars.nftPriceInReserve =
            ((10**vars.reserveDecimals) * vars.nftPriceInETH) /
            vars.reservePriceInETH;

        vars.thresholdPrice = vars.nftPriceInReserve.percentMul(
            vars.liquidationThreshold
        );

        vars.liquidatePrice = vars.nftPriceInReserve.percentMul(
            PercentageMath.PERCENTAGE_FACTOR - vars.liquidationBonus
        );

        return (vars.borrowAmount, vars.thresholdPrice, vars.liquidatePrice);
    }

    struct CalcLoanBuyItNowFineLocalVars {
        uint256 reserveDecimals;
        uint256 reservePriceInETH;
        uint256 baseBuyItNowFineInReserve;
        uint256 minBuyItNowFinePct;
        uint256 minBuyItNowFineInReserve;
        uint256 buyItNowFineInReserve;
        uint256 debtAmount;
    }

    function calculateLoanBuyItNowFine(
        address reserveAsset,
        DataTypes.ReserveData storage reserveData,
        address nftAsset,
        DataTypes.NftData storage nftData,
        DataTypes.LoanData memory loanData,
        address poolLoan,
        address reserveOracle
    ) internal view returns (uint256, uint256) {
        nftAsset;

        if (loanData.buyItNowPrice == 0) {
            return (0, 0);
        }

        CalcLoanBuyItNowFineLocalVars memory vars;

        vars.reserveDecimals = reserveData.configuration.getDecimals();
        vars.reservePriceInETH = IReserveOracleGetter(reserveOracle)
            .getAssetPrice(reserveAsset);
        vars.baseBuyItNowFineInReserve =
            (1 ether * 10**vars.reserveDecimals) /
            vars.reservePriceInETH;

        vars.minBuyItNowFinePct = nftData.configuration.getMinBuyItNowFine();
        vars.minBuyItNowFineInReserve = vars
            .baseBuyItNowFineInReserve
            .percentMul(vars.minBuyItNowFinePct);

        (, vars.debtAmount) = ILendPoolLoan(poolLoan)
            .getLoanReserveBorrowAmount(loanData.loanId);

        vars.buyItNowFineInReserve = vars.debtAmount.percentMul(
            nftData.configuration.getRedeemFine()
        );
        if (vars.buyItNowFineInReserve < vars.minBuyItNowFineInReserve) {
            vars.buyItNowFineInReserve = vars.minBuyItNowFineInReserve;
        }

        return (vars.minBuyItNowFineInReserve, vars.buyItNowFineInReserve);
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {Errors} from "../helpers/Errors.sol";

/**
 * @title PercentageMath library
 * @author Confetti
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded half up
 **/

library PercentageMath {
  uint256 constant PERCENTAGE_FACTOR = 1e4; //percentage plus two decimals
  uint256 constant HALF_PERCENT = PERCENTAGE_FACTOR / 2;
  uint256 constant ONE_PERCENT = 1e2; //100, 1%
  uint256 constant TEN_PERCENT = 1e3; //1000, 10%
  uint256 constant ONE_THOUSANDTH_PERCENT = 1e1; //10, 0.1%
  uint256 constant ONE_TEN_THOUSANDTH_PERCENT = 1; //1, 0.01%

  /**
   * @dev Executes a percentage multiplication
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return The percentage of value
   **/
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256) {
    if (value == 0 || percentage == 0) {
      return 0;
    }

    require(value <= (type(uint256).max - HALF_PERCENT) / percentage, Errors.MATH_MULTIPLICATION_OVERFLOW);

    return (value * percentage + HALF_PERCENT) / PERCENTAGE_FACTOR;
  }

  /**
   * @dev Executes a percentage division
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return The value divided the percentage
   **/
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256) {
    require(percentage != 0, Errors.MATH_DIVISION_BY_ZERO);
    uint256 halfPercentage = percentage / 2;

    require(value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR, Errors.MATH_MULTIPLICATION_OVERFLOW);

    return (value * PERCENTAGE_FACTOR + halfPercentage) / percentage;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ICToken} from "../../interfaces/ICToken.sol";
import {IDebtToken} from "../../interfaces/IDebtToken.sol";
import {IInterestRate} from "../../interfaces/IInterestRate.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title ReserveLogic library
 * @author Confetti
 * @notice Implements the logic to update the reserves state
 */
library ReserveLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev Emitted when the state of a reserve is updated
   * @param asset The address of the underlying asset of the reserve
   * @param liquidityRate The new liquidity rate
   * @param variableBorrowRate The new variable borrow rate
   * @param liquidityIndex The new liquidity index
   * @param variableBorrowIndex The new variable borrow index
   **/
  event ReserveDataUpdated(
    address indexed asset,
    uint256 liquidityRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  using ReserveLogic for DataTypes.ReserveData;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  /**
   * @dev Returns the ongoing normalized income for the reserve
   * A value of 1e27 means there is no income. As time passes, the income is accrued
   * A value of 2*1e27 means for each unit of asset one unit of income has been accrued
   * @param reserve The reserve object
   * @return the normalized income. expressed in ray
   **/
  function getNormalizedIncome(DataTypes.ReserveData storage reserve) internal view returns (uint256) {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == uint40(block.timestamp)) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.liquidityIndex;
    }

    uint256 cumulated = MathUtils.calculateLinearInterest(reserve.currentLiquidityRate, timestamp).rayMul(
      reserve.liquidityIndex
    );

    return cumulated;
  }

  /**
   * @dev Returns the ongoing normalized variable debt for the reserve
   * A value of 1e27 means there is no debt. As time passes, the income is accrued
   * A value of 2*1e27 means that for each unit of debt, one unit worth of interest has been accumulated
   * @param reserve The reserve object
   * @return The normalized variable debt. expressed in ray
   **/
  function getNormalizedDebt(DataTypes.ReserveData storage reserve) internal view returns (uint256) {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == uint40(block.timestamp)) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.variableBorrowIndex;
    }

    uint256 cumulated = MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, timestamp).rayMul(
      reserve.variableBorrowIndex
    );

    return cumulated;
  }

  /**
   * @dev Updates the liquidity cumulative index and the variable borrow index.
   * @param reserve the reserve object
   **/
  function updateState(DataTypes.ReserveData storage reserve) internal {
    uint256 scaledVariableDebt = IDebtToken(reserve.debtTokenAddress).scaledTotalSupply();
    uint256 previousVariableBorrowIndex = reserve.variableBorrowIndex;
    uint256 previousLiquidityIndex = reserve.liquidityIndex;
    uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;

    (uint256 newLiquidityIndex, uint256 newVariableBorrowIndex) = _updateIndexes(
      reserve,
      scaledVariableDebt,
      previousLiquidityIndex,
      previousVariableBorrowIndex,
      lastUpdatedTimestamp
    );

    _mintToTreasury(
      reserve,
      scaledVariableDebt,
      previousVariableBorrowIndex,
      newLiquidityIndex,
      newVariableBorrowIndex,
      lastUpdatedTimestamp
    );
  }

  /**
   * @dev Accumulates a predefined amount of asset to the reserve as a fixed, instantaneous income. Used for example to accumulate
   * the flashloan fee to the reserve, and spread it between all the depositors
   * @param reserve The reserve object
   * @param totalLiquidity The total liquidity available in the reserve
   * @param amount The amount to accomulate
   **/
  function cumulateToLiquidityIndex(
    DataTypes.ReserveData storage reserve,
    uint256 totalLiquidity,
    uint256 amount
  ) internal {
    uint256 amountToLiquidityRatio = amount.wadToRay().rayDiv(totalLiquidity.wadToRay());

    uint256 result = amountToLiquidityRatio + (WadRayMath.ray());

    result = result.rayMul(reserve.liquidityIndex);
    require(result <= type(uint128).max, Errors.RL_LIQUIDITY_INDEX_OVERFLOW);

    reserve.liquidityIndex = uint128(result);
  }

  /**
   * @dev Initializes a reserve
   * @param reserve The reserve object
   * @param cTokenAddress The address of the overlying cToken contract
   * @param debtTokenAddress The address of the overlying debtToken contract
   * @param interestRateAddress The address of the interest rate strategy contract
   **/
  function init(
    DataTypes.ReserveData storage reserve,
    address cTokenAddress,
    address debtTokenAddress,
    address interestRateAddress
  ) external {
    require(reserve.cTokenAddress == address(0), Errors.RL_RESERVE_ALREADY_INITIALIZED);

    reserve.liquidityIndex = uint128(WadRayMath.ray());
    reserve.variableBorrowIndex = uint128(WadRayMath.ray());
    reserve.cTokenAddress = cTokenAddress;
    reserve.debtTokenAddress = debtTokenAddress;
    reserve.interestRateAddress = interestRateAddress;
  }

  struct UpdateInterestRatesLocalVars {
    uint256 availableLiquidity;
    uint256 newLiquidityRate;
    uint256 newVariableRate;
    uint256 totalVariableDebt;
  }

  /**
   * @dev Updates the reserve current stable borrow rate, the current variable borrow rate and the current liquidity rate
   * @param reserve The address of the reserve to be updated
   * @param liquidityAdded The amount of liquidity added to the protocol (deposit or repay) in the previous action
   * @param liquidityTaken The amount of liquidity taken from the protocol (withdraw or borrow)
   **/
  function updateInterestRates(
    DataTypes.ReserveData storage reserve,
    address reserveAddress,
    address cTokenAddress,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    UpdateInterestRatesLocalVars memory vars;

    //calculates the total variable debt locally using the scaled borrow amount instead
    //of borrow amount(), as it's noticeably cheaper. Also, the index has been
    //updated by the previous updateState() call
    vars.totalVariableDebt = IDebtToken(reserve.debtTokenAddress).scaledTotalSupply().rayMul(
      reserve.variableBorrowIndex
    );

    (vars.newLiquidityRate, vars.newVariableRate) = IInterestRate(reserve.interestRateAddress).calculateInterestRates(
      reserveAddress,
      cTokenAddress,
      liquidityAdded,
      liquidityTaken,
      vars.totalVariableDebt,
      reserve.configuration.getReserveFactor()
    );
    require(vars.newLiquidityRate <= type(uint128).max, Errors.RL_LIQUIDITY_RATE_OVERFLOW);
    require(vars.newVariableRate <= type(uint128).max, Errors.RL_VARIABLE_BORROW_RATE_OVERFLOW);

    reserve.currentLiquidityRate = uint128(vars.newLiquidityRate);
    reserve.currentVariableBorrowRate = uint128(vars.newVariableRate);

    emit ReserveDataUpdated(
      reserveAddress,
      vars.newLiquidityRate,
      vars.newVariableRate,
      reserve.liquidityIndex,
      reserve.variableBorrowIndex
    );
  }

  struct MintToTreasuryLocalVars {
    uint256 currentVariableDebt;
    uint256 previousVariableDebt;
    uint256 totalDebtAccrued;
    uint256 amountToMint;
    uint256 reserveFactor;
  }

  /**
   * @dev Mints part of the repaid interest to the reserve treasury as a function of the reserveFactor for the
   * specific asset.
   * @param reserve The reserve reserve to be updated
   * @param scaledVariableDebt The current scaled total variable debt
   * @param previousVariableBorrowIndex The variable borrow index before the last accumulation of the interest
   * @param newLiquidityIndex The new liquidity index
   * @param newVariableBorrowIndex The variable borrow index after the last accumulation of the interest
   **/
  function _mintToTreasury(
    DataTypes.ReserveData storage reserve,
    uint256 scaledVariableDebt,
    uint256 previousVariableBorrowIndex,
    uint256 newLiquidityIndex,
    uint256 newVariableBorrowIndex,
    uint40 timestamp
  ) internal {
    timestamp;
    MintToTreasuryLocalVars memory vars;

    vars.reserveFactor = reserve.configuration.getReserveFactor();

    if (vars.reserveFactor == 0) {
      return;
    }

    //calculate the last principal variable debt
    vars.previousVariableDebt = scaledVariableDebt.rayMul(previousVariableBorrowIndex);

    //calculate the new total supply after accumulation of the index
    vars.currentVariableDebt = scaledVariableDebt.rayMul(newVariableBorrowIndex);

    //debt accrued is the sum of the current debt minus the sum of the debt at the last update
    vars.totalDebtAccrued = vars.currentVariableDebt - (vars.previousVariableDebt);

    vars.amountToMint = vars.totalDebtAccrued.percentMul(vars.reserveFactor);

    if (vars.amountToMint != 0) {
      ICToken(reserve.cTokenAddress).mintToTreasury(vars.amountToMint, newLiquidityIndex);
    }
  }

  /**
   * @dev Updates the reserve indexes and the timestamp of the update
   * @param reserve The reserve reserve to be updated
   * @param scaledVariableDebt The scaled variable debt
   * @param liquidityIndex The last stored liquidity index
   * @param variableBorrowIndex The last stored variable borrow index
   **/
  function _updateIndexes(
    DataTypes.ReserveData storage reserve,
    uint256 scaledVariableDebt,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex,
    uint40 timestamp
  ) internal returns (uint256, uint256) {
    uint256 currentLiquidityRate = reserve.currentLiquidityRate;

    uint256 newLiquidityIndex = liquidityIndex;
    uint256 newVariableBorrowIndex = variableBorrowIndex;

    //only cumulating if there is any income being produced
    if (currentLiquidityRate > 0) {
      uint256 cumulatedLiquidityInterest = MathUtils.calculateLinearInterest(currentLiquidityRate, timestamp);
      newLiquidityIndex = cumulatedLiquidityInterest.rayMul(liquidityIndex);
      require(newLiquidityIndex <= type(uint128).max, Errors.RL_LIQUIDITY_INDEX_OVERFLOW);

      reserve.liquidityIndex = uint128(newLiquidityIndex);

      //as the liquidity rate might come only from stable rate loans, we need to ensure
      //that there is actual variable debt before accumulating
      if (scaledVariableDebt != 0) {
        uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(
          reserve.currentVariableBorrowRate,
          timestamp
        );
        newVariableBorrowIndex = cumulatedVariableBorrowInterest.rayMul(variableBorrowIndex);
        require(newVariableBorrowIndex <= type(uint128).max, Errors.RL_VARIABLE_BORROW_INDEX_OVERFLOW);
        reserve.variableBorrowIndex = uint128(newVariableBorrowIndex);
      }
    }

    //solium-disable-next-line
    reserve.lastUpdateTimestamp = uint40(block.timestamp);
    return (newLiquidityIndex, newVariableBorrowIndex);
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title NftLogic library
 * @author Confetti
 * @notice Implements the logic to update the nft state
 */
library NftLogic {
  /**
   * @dev Initializes a nft
   * @param nft The nft object
   * @param cNFTAddress The address of the cNFT contract
   **/
  function init(DataTypes.NftData storage nft, address cNFTAddress) external {
    require(nft.cNFTAddress == address(0), Errors.RL_RESERVE_ALREADY_INITIALIZED);

    nft.cNFTAddress = cNFTAddress;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ReserveLogic} from "./ReserveLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {NftConfiguration} from "../configuration/NftConfiguration.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {IInterestRate} from "../../interfaces/IInterestRate.sol";
import {ILendPoolLoan} from "../../interfaces/ILendPoolLoan.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title ValidationLogic library
 * @author Confetti
 * @notice Implements functions to validate the different actions of the protocol
 */
library ValidationLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using NftConfiguration for DataTypes.NftConfigurationMap;

    /**
     * @dev Validates a deposit action
     * @param reserve The reserve object on which the user is depositing
     * @param amount The amount to be deposited
     */
    function validateDeposit(
        DataTypes.ReserveData storage reserve,
        uint256 amount
    ) external view {
        (bool isActive, bool isFrozen, , ) = reserve.configuration.getFlags();

        require(amount != 0, Errors.VL_INVALID_AMOUNT);
        require(isActive, Errors.VL_NO_ACTIVE_RESERVE);
        require(!isFrozen, Errors.VL_RESERVE_FROZEN);
    }

    /**
     * @dev Validates a withdraw action
     * @param reserveData The reserve state
     * @param amount The amount to be withdrawn
     * @param userBalance The balance of the user
     */
    function validateWithdraw(
        DataTypes.ReserveData storage reserveData,
        uint256 amount,
        uint256 userBalance
    ) external view {
        require(amount != 0, Errors.VL_INVALID_AMOUNT);
        require(
            amount <= userBalance,
            Errors.VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE
        );

        (bool isActive, , , ) = reserveData.configuration.getFlags();
        require(isActive, Errors.VL_NO_ACTIVE_RESERVE);
    }

    struct ValidateBorrowLocalVars {
        uint256 currentLtv;
        uint256 currentLiquidationThreshold;
        uint256 amountOfCollateralNeeded;
        uint256 userCollateralBalance;
        uint256 userBorrowBalance;
        uint256 availableLiquidity;
        uint256 healthFactor;
        bool isActive;
        bool isFrozen;
        bool borrowingEnabled;
        bool stableRateBorrowingEnabled;
        bool nftIsActive;
        bool nftIsFrozen;
        address loanReserveAsset;
        address loanBorrower;
    }

    /**
     * @dev Validates a borrow action
     * @param reserveAsset The address of the asset to borrow
     * @param amount The amount to be borrowed
     * @param reserveData The reserve state from which the user is borrowing
     * @param nftData The state of the user for the specific nft
     */
    function validateBorrow(
        address user,
        address reserveAsset,
        uint256 amount,
        DataTypes.ReserveData storage reserveData,
        address nftAsset,
        DataTypes.NftData storage nftData,
        address loanAddress,
        uint256 loanId,
        address reserveOracle,
        address nftOracle
    ) external view {
        ValidateBorrowLocalVars memory vars;

        require(
            reserveData.cTokenAddress != address(0),
            Errors.VL_INVALID_RESERVE_ADDRESS
        );
        require(
            nftData.cNFTAddress != address(0),
            Errors.LPC_INVALIED_CNFT_ADDRESS
        );
        require(amount > 0, Errors.VL_INVALID_AMOUNT);

        if (loanId != 0) {
            DataTypes.LoanData memory loanData = ILendPoolLoan(loanAddress)
                .getLoan(loanId);

            require(
                loanData.state == DataTypes.LoanState.Active,
                Errors.LPL_INVALID_LOAN_STATE
            );
            require(
                reserveAsset == loanData.reserveAsset,
                Errors.VL_SPECIFIED_RESERVE_NOT_BORROWED_BY_USER
            );
            require(
                user == loanData.borrower,
                Errors.VL_SPECIFIED_LOAN_NOT_BORROWED_BY_USER
            );
        }

        (
            vars.isActive,
            vars.isFrozen,
            vars.borrowingEnabled,
            vars.stableRateBorrowingEnabled
        ) = reserveData.configuration.getFlags();
        require(vars.isActive, Errors.VL_NO_ACTIVE_RESERVE);
        require(!vars.isFrozen, Errors.VL_RESERVE_FROZEN);
        require(vars.borrowingEnabled, Errors.VL_BORROWING_NOT_ENABLED);

        (vars.nftIsActive, vars.nftIsFrozen) = nftData.configuration.getFlags();
        require(vars.nftIsActive, Errors.VL_NO_ACTIVE_NFT);
        require(!vars.nftIsFrozen, Errors.VL_NFT_FROZEN);

        (vars.currentLtv, vars.currentLiquidationThreshold, ) = nftData
            .configuration
            .getCollateralParams();

        (
            vars.userCollateralBalance,
            vars.userBorrowBalance,
            vars.healthFactor
        ) = GenericLogic.calculateLoanData(
            reserveAsset,
            reserveData,
            nftAsset,
            nftData,
            loanAddress,
            loanId,
            reserveOracle,
            nftOracle
        );

        require(
            vars.userCollateralBalance > 0,
            Errors.VL_COLLATERAL_BALANCE_IS_0
        );

        require(
            vars.healthFactor >
                GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            Errors.VL_HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
        );

        //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
        //LTV is calculated in percentage
        vars.amountOfCollateralNeeded = (vars.userBorrowBalance + amount)
            .percentDiv(vars.currentLtv);

        require(
            vars.amountOfCollateralNeeded <= vars.userCollateralBalance,
            Errors.VL_COLLATERAL_CANNOT_COVER_NEW_BORROW
        );
    }

    /**
     * @dev Validates a repay action
     * @param reserveData The reserve state from which the user is repaying
     * @param amountSent The amount sent for the repayment. Can be an actual value or uint(-1)
     * @param borrowAmount The borrow balance of the user
     */
    function validateRepay(
        DataTypes.ReserveData storage reserveData,
        DataTypes.NftData storage nftData,
        DataTypes.LoanData memory loanData,
        uint256 amountSent,
        uint256 borrowAmount
    ) external view {
        require(
            nftData.cNFTAddress != address(0),
            Errors.LPC_INVALIED_CNFT_ADDRESS
        );
        require(
            reserveData.cTokenAddress != address(0),
            Errors.VL_INVALID_RESERVE_ADDRESS
        );

        require(
            reserveData.configuration.getActive(),
            Errors.VL_NO_ACTIVE_RESERVE
        );

        require(nftData.configuration.getActive(), Errors.VL_NO_ACTIVE_NFT);

        require(amountSent > 0, Errors.VL_INVALID_AMOUNT);

        require(borrowAmount > 0, Errors.VL_NO_DEBT_OF_SELECTED_TYPE);

        require(
            loanData.state == DataTypes.LoanState.Active,
            Errors.LPL_INVALID_LOAN_STATE
        );
    }

    /**
     * @dev Validates the buy-it-now action
     * @param reserveData The reserve data of the principal
     * @param nftData The nft data of the underlying nft
     * @param buyItNowPrice Total variable debt balance of the user
     **/
    function validateBuyItNow(
        DataTypes.ReserveData storage reserveData,
        DataTypes.NftData storage nftData,
        DataTypes.LoanData memory loanData,
        uint256 buyItNowPrice
    ) internal view {
        require(
            nftData.cNFTAddress != address(0),
            Errors.LPC_INVALIED_CNFT_ADDRESS
        );
        require(
            reserveData.cTokenAddress != address(0),
            Errors.VL_INVALID_RESERVE_ADDRESS
        );

        require(
            reserveData.configuration.getActive(),
            Errors.VL_NO_ACTIVE_RESERVE
        );

        require(nftData.configuration.getActive(), Errors.VL_NO_ACTIVE_NFT);

        require(
            loanData.state == DataTypes.LoanState.Active ||
                loanData.state == DataTypes.LoanState.BuyItNow,
            Errors.LPL_INVALID_LOAN_STATE
        );

        require(buyItNowPrice > 0, Errors.VL_INVALID_AMOUNT);
    }

    /**
     * @dev Validates a redeem action
     * @param reserveData The reserve state
     * @param nftData The nft state
     */
    function validateRedeem(
        DataTypes.ReserveData storage reserveData,
        DataTypes.NftData storage nftData,
        DataTypes.LoanData memory loanData,
        uint256 amount
    ) external view {
        require(
            nftData.cNFTAddress != address(0),
            Errors.LPC_INVALIED_CNFT_ADDRESS
        );
        require(
            reserveData.cTokenAddress != address(0),
            Errors.VL_INVALID_RESERVE_ADDRESS
        );

        require(
            reserveData.configuration.getActive(),
            Errors.VL_NO_ACTIVE_RESERVE
        );

        require(nftData.configuration.getActive(), Errors.VL_NO_ACTIVE_NFT);

        require(
            loanData.state == DataTypes.LoanState.BuyItNow,
            Errors.LPL_INVALID_LOAN_STATE
        );

        require(
            loanData.buyItNowBuyerAddress != address(0),
            Errors.LPL_INVALID_BUYITNOW_BUYER_ADDRESS
        );

        require(amount > 0, Errors.VL_INVALID_AMOUNT);
    }

    /**
     * @dev Validates the liquidation action
     * @param reserveData The reserve data of the principal
     * @param nftData The data of the underlying NFT
     * @param loanData The loan data of the underlying NFT
     **/
    function validateLiquidate(
        DataTypes.ReserveData storage reserveData,
        DataTypes.NftData storage nftData,
        DataTypes.LoanData memory loanData
    ) internal view {
        require(
            nftData.cNFTAddress != address(0),
            Errors.LPC_INVALIED_CNFT_ADDRESS
        );
        require(
            reserveData.cTokenAddress != address(0),
            Errors.VL_INVALID_RESERVE_ADDRESS
        );

        require(
            reserveData.configuration.getActive(),
            Errors.VL_NO_ACTIVE_RESERVE
        );

        require(nftData.configuration.getActive(), Errors.VL_NO_ACTIVE_NFT);

        require(
            loanData.state == DataTypes.LoanState.BuyItNow,
            Errors.LPL_INVALID_LOAN_STATE
        );

        require(
            loanData.buyItNowBuyerAddress != address(0),
            Errors.LPL_INVALID_BUYITNOW_BUYER_ADDRESS
        );
    }

    /**
     * @dev Validates an cToken transfer
     * @param from The user from which the cTokens are being transferred
     * @param reserveData The state of the reserve
     */
    function validateTransfer(
        address from,
        DataTypes.ReserveData storage reserveData
    ) internal pure {
        from;
        reserveData;
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ICToken} from "../../interfaces/ICToken.sol";

import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {ReserveLogic} from "./ReserveLogic.sol";
import {ValidationLogic} from "./ValidationLogic.sol";

/**
 * @title SupplyLogic library
 * @author Confetti
 * @notice Implements the logic to supply feature
 */
library SupplyLogic {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ReserveLogic for DataTypes.ReserveData;

  /**
   * @dev Emitted on deposit()
   * @param user The address initiating the deposit
   * @param amount The amount deposited
   * @param reserve The address of the underlying asset of the reserve
   * @param onBehalfOf The beneficiary of the deposit, receiving the cTokens
   * @param referral The referral code used
   **/
  event Deposit(
    address user,
    address indexed reserve,
    uint256 amount,
    address indexed onBehalfOf,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on withdraw()
   * @param user The address initiating the withdrawal, owner of cTokens
   * @param reserve The address of the underlyng asset being withdrawn
   * @param amount The amount to be withdrawn
   * @param to Address that will receive the underlying
   **/
  event Withdraw(address indexed user, address indexed reserve, uint256 amount, address indexed to);

  /**
   * @notice Implements the supply feature. Through `deposit()`, users deposit assets to the protocol.
   * @dev Emits the `Deposit()` event.
   * @param reservesData The state of all the reserves
   * @param params The additional parameters needed to execute the deposit function
   */
  function executeDeposit(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.ExecuteDepositParams memory params
  ) external {
    require(params.onBehalfOf != address(0), Errors.VL_INVALID_ONBEHALFOF_ADDRESS);

    DataTypes.ReserveData storage reserve = reservesData[params.asset];
    address cToken = reserve.cTokenAddress;
    require(cToken != address(0), Errors.VL_INVALID_RESERVE_ADDRESS);

    ValidationLogic.validateDeposit(reserve, params.amount);

    reserve.updateState();
    reserve.updateInterestRates(params.asset, cToken, params.amount, 0);

    IERC20Upgradeable(params.asset).safeTransferFrom(params.initiator, cToken, params.amount);

    ICToken(cToken).mint(params.onBehalfOf, params.amount, reserve.liquidityIndex);

    emit Deposit(params.initiator, params.asset, params.amount, params.onBehalfOf, params.referralCode);
  }

  /**
   * @notice Implements the supply feature. Through `withdraw()`, users withdraw assets from the protocol.
   * @dev Emits the `Withdraw()` event.
   * @param reservesData The state of all the reserves
   * @param params The additional parameters needed to execute the withdraw function
   */
  function executeWithdraw(
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.ExecuteWithdrawParams memory params
  ) external returns (uint256) {
    require(params.to != address(0), Errors.VL_INVALID_TARGET_ADDRESS);

    DataTypes.ReserveData storage reserve = reservesData[params.asset];
    address cToken = reserve.cTokenAddress;
    require(cToken != address(0), Errors.VL_INVALID_RESERVE_ADDRESS);

    uint256 userBalance = ICToken(cToken).balanceOf(params.initiator);

    uint256 amountToWithdraw = params.amount;

    if (params.amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }

    ValidationLogic.validateWithdraw(reserve, amountToWithdraw, userBalance);

    reserve.updateState();

    reserve.updateInterestRates(params.asset, cToken, 0, amountToWithdraw);

    ICToken(cToken).burn(params.initiator, params.to, amountToWithdraw, reserve.liquidityIndex);

    emit Withdraw(params.initiator, params.asset, amountToWithdraw, params.to);

    return amountToWithdraw;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ICToken} from "../../interfaces/ICToken.sol";
import {IDebtToken} from "../../interfaces/IDebtToken.sol";
import {IInterestRate} from "../../interfaces/IInterestRate.sol";
import {ILendPoolAddressesProvider} from "../../interfaces/ILendPoolAddressesProvider.sol";
import {IReserveOracleGetter} from "../../interfaces/IReserveOracleGetter.sol";
import {INFTOracleGetter} from "../../interfaces/INFTOracleGetter.sol";
import {ILendPoolLoan} from "../../interfaces/ILendPoolLoan.sol";

import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import {ReserveLogic} from "./ReserveLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";
import {ValidationLogic} from "./ValidationLogic.sol";

/**
 * @title BorrowLogic library
 * @author Confetti
 * @notice Implements the logic to borrow feature
 */
library BorrowLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using ReserveLogic for DataTypes.ReserveData;

  /**
   * @dev Emitted on borrow() when loan needs to be opened
   * @param user The address of the user initiating the borrow(), receiving the funds
   * @param reserve The address of the underlying asset being borrowed
   * @param amount The amount borrowed out
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token id of the underlying NFT used as collateral
   * @param onBehalfOf The address that will be getting the loan
   * @param referral The referral code used
   **/
  event Borrow(
    address user,
    address indexed reserve,
    uint256 amount,
    address nftAsset,
    uint256 nftTokenId,
    address indexed onBehalfOf,
    uint256 borrowRate,
    uint256 loanId,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on repay()
   * @param user The address of the user initiating the repay(), providing the funds
   * @param reserve The address of the underlying asset of the reserve
   * @param amount The amount repaid
   * @param nftAsset The address of the underlying NFT used as collateral
   * @param nftTokenId The token id of the underlying NFT used as collateral
   * @param borrower The beneficiary of the repayment, getting his debt reduced
   * @param loanId The loan ID of the NFT loans
   **/
  event Repay(
    address user,
    address indexed reserve,
    uint256 amount,
    address indexed nftAsset,
    uint256 nftTokenId,
    address indexed borrower,
    uint256 loanId
  );

  struct ExecuteBorrowLocalVars {
    address initiator;
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    uint256 loanId;
    address reserveOracle;
    address nftOracle;
    address loanAddress;
  }

  /**
   * @notice Implements the borrow feature. Through `borrow()`, users borrow assets from the protocol.
   * @dev Emits the `Borrow()` event.
   * @param reservesData The state of all the reserves
   * @param nftsData The state of all the nfts
   * @param params The additional parameters needed to execute the borrow function
   */
  function executeBorrow(
    ILendPoolAddressesProvider addressesProvider,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(address => DataTypes.NftData) storage nftsData,
    DataTypes.ExecuteBorrowParams memory params
  ) external {
    _borrow(addressesProvider, reservesData, nftsData, params);
  }

  /**
   * @notice Implements the batch borrow feature. Through `batchBorrow()`, users repay borrow to the protocol.
   * @dev Emits the `Borrow()` event.
   * @param reservesData The state of all the reserves
   * @param nftsData The state of all the nfts
   * @param params The additional parameters needed to execute the batchBorrow function
   */
  function executeBatchBorrow(
    ILendPoolAddressesProvider addressesProvider,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(address => DataTypes.NftData) storage nftsData,
    DataTypes.ExecuteBatchBorrowParams memory params
  ) external {
    require(params.nftAssets.length == params.assets.length, "inconsistent assets length");
    require(params.nftAssets.length == params.amounts.length, "inconsistent amounts length");
    require(params.nftAssets.length == params.nftTokenIds.length, "inconsistent tokenIds length");

    for (uint256 i = 0; i < params.nftAssets.length; i++) {
      _borrow(
        addressesProvider,
        reservesData,
        nftsData,
        DataTypes.ExecuteBorrowParams({
          initiator: params.initiator,
          asset: params.assets[i],
          amount: params.amounts[i],
          nftAsset: params.nftAssets[i],
          nftTokenId: params.nftTokenIds[i],
          onBehalfOf: params.onBehalfOf,
          referralCode: params.referralCode
        })
      );
    }
  }

  function _borrow(
    ILendPoolAddressesProvider addressesProvider,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(address => DataTypes.NftData) storage nftsData,
    DataTypes.ExecuteBorrowParams memory params
  ) internal {
    require(params.onBehalfOf != address(0), Errors.VL_INVALID_ONBEHALFOF_ADDRESS);

    ExecuteBorrowLocalVars memory vars;
    vars.initiator = params.initiator;

    DataTypes.ReserveData storage reserveData = reservesData[params.asset];
    DataTypes.NftData storage nftData = nftsData[params.nftAsset];

    // update state MUST BEFORE get borrow amount which is depent on latest borrow index
    reserveData.updateState();

    // Convert asset amount to ETH
    vars.reserveOracle = addressesProvider.getReserveOracle();
    vars.nftOracle = addressesProvider.getNFTOracle();
    vars.loanAddress = addressesProvider.getLendPoolLoan();

    vars.loanId = ILendPoolLoan(vars.loanAddress).getCollateralLoanId(params.nftAsset, params.nftTokenId);

    ValidationLogic.validateBorrow(
      params.onBehalfOf,
      params.asset,
      params.amount,
      reserveData,
      params.nftAsset,
      nftData,
      vars.loanAddress,
      vars.loanId,
      vars.reserveOracle,
      vars.nftOracle
    );

    if (vars.loanId == 0) {
      IERC721Upgradeable(params.nftAsset).safeTransferFrom(vars.initiator, address(this), params.nftTokenId);

      vars.loanId = ILendPoolLoan(vars.loanAddress).createLoan(
        vars.initiator,
        params.onBehalfOf,
        params.nftAsset,
        params.nftTokenId,
        nftData.cNFTAddress,
        params.asset,
        params.amount,
        reserveData.variableBorrowIndex
      );
    } else {
      ILendPoolLoan(vars.loanAddress).updateLoan(
        vars.initiator,
        vars.loanId,
        params.amount,
        0,
        reserveData.variableBorrowIndex
      );
    }

    IDebtToken(reserveData.debtTokenAddress).mint(
      vars.initiator,
      params.onBehalfOf,
      params.amount,
      reserveData.variableBorrowIndex
    );

    // update interest rate according latest borrow amount (utilizaton)
    reserveData.updateInterestRates(params.asset, reserveData.cTokenAddress, 0, params.amount);

    ICToken(reserveData.cTokenAddress).transferUnderlyingTo(vars.initiator, params.amount);

    emit Borrow(
      vars.initiator,
      params.asset,
      params.amount,
      params.nftAsset,
      params.nftTokenId,
      params.onBehalfOf,
      reserveData.currentVariableBorrowRate,
      vars.loanId,
      params.referralCode
    );
  }

  struct RepayLocalVars {
    address initiator;
    address poolLoan;
    address onBehalfOf;
    uint256 loanId;
    bool isUpdate;
    uint256 borrowAmount;
    uint256 repayAmount;
  }

  /**
   * @notice Implements the borrow feature. Through `repay()`, users repay assets to the protocol.
   * @dev Emits the `Repay()` event.
   * @param reservesData The state of all the reserves
   * @param nftsData The state of all the nfts
   * @param params The additional parameters needed to execute the repay function
   */
  function executeRepay(
    ILendPoolAddressesProvider addressesProvider,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(address => DataTypes.NftData) storage nftsData,
    DataTypes.ExecuteRepayParams memory params
  ) external returns (uint256, bool) {
    return _repay(addressesProvider, reservesData, nftsData, params);
  }

  /**
   * @notice Implements the batch repay feature. Through `batchRepay()`, users repay assets to the protocol.
   * @dev Emits the `repay()` event.
   * @param reservesData The state of all the reserves
   * @param nftsData The state of all the nfts
   * @param params The additional parameters needed to execute the batchRepay function
   */
  function executeBatchRepay(
    ILendPoolAddressesProvider addressesProvider,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(address => DataTypes.NftData) storage nftsData,
    DataTypes.ExecuteBatchRepayParams memory params
  ) external returns (uint256[] memory, bool[] memory) {
    require(params.nftAssets.length == params.amounts.length, "inconsistent amounts length");
    require(params.nftAssets.length == params.nftTokenIds.length, "inconsistent tokenIds length");

    uint256[] memory repayAmounts = new uint256[](params.nftAssets.length);
    bool[] memory repayAlls = new bool[](params.nftAssets.length);

    for (uint256 i = 0; i < params.nftAssets.length; i++) {
      (repayAmounts[i], repayAlls[i]) = _repay(
        addressesProvider,
        reservesData,
        nftsData,
        DataTypes.ExecuteRepayParams({
          initiator: params.initiator,
          nftAsset: params.nftAssets[i],
          nftTokenId: params.nftTokenIds[i],
          amount: params.amounts[i]
        })
      );
    }

    return (repayAmounts, repayAlls);
  }

  function _repay(
    ILendPoolAddressesProvider addressesProvider,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    mapping(address => DataTypes.NftData) storage nftsData,
    DataTypes.ExecuteRepayParams memory params
  ) internal returns (uint256, bool) {
    RepayLocalVars memory vars;
    vars.initiator = params.initiator;

    vars.poolLoan = addressesProvider.getLendPoolLoan();

    vars.loanId = ILendPoolLoan(vars.poolLoan).getCollateralLoanId(params.nftAsset, params.nftTokenId);
    require(vars.loanId != 0, Errors.LP_NFT_IS_NOT_USED_AS_COLLATERAL);

    DataTypes.LoanData memory loanData = ILendPoolLoan(vars.poolLoan).getLoan(vars.loanId);

    DataTypes.ReserveData storage reserveData = reservesData[loanData.reserveAsset];
    DataTypes.NftData storage nftData = nftsData[loanData.nftAsset];

    // update state MUST BEFORE get borrow amount which is depent on latest borrow index
    reserveData.updateState();

    (, vars.borrowAmount) = ILendPoolLoan(vars.poolLoan).getLoanReserveBorrowAmount(vars.loanId);

    ValidationLogic.validateRepay(reserveData, nftData, loanData, params.amount, vars.borrowAmount);

    vars.repayAmount = vars.borrowAmount;
    vars.isUpdate = false;
    if (params.amount < vars.repayAmount) {
      vars.isUpdate = true;
      vars.repayAmount = params.amount;
    }

    if (vars.isUpdate) {
      ILendPoolLoan(vars.poolLoan).updateLoan(
        vars.initiator,
        vars.loanId,
        0,
        vars.repayAmount,
        reserveData.variableBorrowIndex
      );
    } else {
      ILendPoolLoan(vars.poolLoan).repayLoan(
        vars.initiator,
        vars.loanId,
        nftData.cNFTAddress,
        vars.repayAmount,
        reserveData.variableBorrowIndex
      );
    }

    IDebtToken(reserveData.debtTokenAddress).burn(loanData.borrower, vars.repayAmount, reserveData.variableBorrowIndex);

    // update interest rate according latest borrow amount (utilizaton)
    reserveData.updateInterestRates(loanData.reserveAsset, reserveData.cTokenAddress, vars.repayAmount, 0);

    // transfer repay amount to cToken
    IERC20Upgradeable(loanData.reserveAsset).safeTransferFrom(
      vars.initiator,
      reserveData.cTokenAddress,
      vars.repayAmount
    );

    // transfer erc721 to borrower
    if (!vars.isUpdate) {
      IERC721Upgradeable(loanData.nftAsset).safeTransferFrom(address(this), loanData.borrower, params.nftTokenId);
    }

    emit Repay(
      vars.initiator,
      loanData.reserveAsset,
      vars.repayAmount,
      loanData.nftAsset,
      loanData.nftTokenId,
      loanData.borrower,
      vars.loanId
    );

    return (vars.repayAmount, !vars.isUpdate);
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ICToken} from "../../interfaces/ICToken.sol";
import {IDebtToken} from "../../interfaces/IDebtToken.sol";
import {IInterestRate} from "../../interfaces/IInterestRate.sol";
import {ILendPoolAddressesProvider} from "../../interfaces/ILendPoolAddressesProvider.sol";
import {IReserveOracleGetter} from "../../interfaces/IReserveOracleGetter.sol";
import {INFTOracleGetter} from "../../interfaces/INFTOracleGetter.sol";
import {ILendPoolLoan} from "../../interfaces/ILendPoolLoan.sol";

import {ReserveLogic} from "./ReserveLogic.sol";
import {GenericLogic} from "./GenericLogic.sol";
import {ValidationLogic} from "./ValidationLogic.sol";

import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {NftConfiguration} from "../configuration/NftConfiguration.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/**
 * @title LiquidateLogic library
 * @author Confetti
 * @notice Implements the logic to liquidate feature
 */
library LiquidateLogic {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using NftConfiguration for DataTypes.NftConfigurationMap;

    /**
     * @dev Emitted when a borrower's loan is set to buy-it-now.
     * @param user The address of the user initiating the buy-it-now
     * @param reserve The address of the underlying asset of the reserve
     * @param buyItNowPrice The price of the underlying reserve given by the buy-it-now buyer
     * @param nftAsset The address of the underlying NFT used as collateral
     * @param nftTokenId The token id of the underlying NFT used as collateral
     * @param onBehalfOf The address that will be getting the NFT
     * @param loanId The loan ID of the NFT loans
     **/
    event BuyItNow(
        address user,
        address indexed reserve,
        uint256 buyItNowPrice,
        address indexed nftAsset,
        uint256 nftTokenId,
        address onBehalfOf,
        address indexed borrower,
        uint256 loanId
    );

    /**
     * @dev Emitted on redeem()
     * @param user The address of the user initiating the redeem(), providing the funds
     * @param reserve The address of the underlying asset of the reserve
     * @param borrowAmount The borrow amount repaid
     * @param nftAsset The address of the underlying NFT used as collateral
     * @param nftTokenId The token id of the underlying NFT used as collateral
     * @param loanId The loan ID of the NFT loans
     **/
    event Redeem(
        address user,
        address indexed reserve,
        uint256 borrowAmount,
        uint256 fineAmount,
        address indexed nftAsset,
        uint256 nftTokenId,
        address indexed borrower,
        uint256 loanId
    );

    /**
     * @dev Emitted when a borrower's loan is liquidated.
     * @param user The address of the user initiating the buy-it-now sale
     * @param reserve The address of the underlying asset of the reserve
     * @param repayAmount The amount of reserve repaid by the liquidator
     * @param remainAmount The amount of reserve received by the borrower
     * @param loanId The loan ID of the NFT loans
     **/
    event Liquidate(
        address user,
        address indexed reserve,
        uint256 repayAmount,
        uint256 remainAmount,
        address indexed nftAsset,
        uint256 nftTokenId,
        address indexed borrower,
        uint256 loanId
    );

    struct BuyItNowLocalVars {
        address loanAddress;
        address reserveOracle;
        address nftOracle;
        address initiator;
        uint256 loanId;
        uint256 thresholdPrice;
        uint256 liquidatePrice;
        uint256 borrowAmount;
        uint256 buyItNowEndTimestamp;
        uint256 minBuyItNowDelta;
    }

    /**
     * @notice Implements the buy-it-now sale feature. Through `buyItNow()`, users set  assets to buy it now in the protocol.
     * @dev Emits the `BuyItNow()` event.
     * @param reservesData The state of all the reserves
     * @param nftsData The state of all the nfts
     * @param params The additional parameters needed to execute the buyItNow function
     */
    // Moves an NFT into buy-it-now (auction) state and sets buy-it-now price, allowing user to liquidate
    function executeBuyItNow(
        ILendPoolAddressesProvider addressesProvider,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(address => DataTypes.NftData) storage nftsData,
        DataTypes.ExecuteBuyItNowParams memory params
    ) external {
        require(
            params.onBehalfOf != address(0),
            Errors.VL_INVALID_ONBEHALFOF_ADDRESS
        );

        BuyItNowLocalVars memory vars;
        vars.initiator = params.initiator;

        vars.loanAddress = addressesProvider.getLendPoolLoan();
        vars.reserveOracle = addressesProvider.getReserveOracle();
        vars.nftOracle = addressesProvider.getNFTOracle();

        vars.loanId = ILendPoolLoan(vars.loanAddress).getCollateralLoanId(
            params.nftAsset,
            params.nftTokenId
        );
        require(vars.loanId != 0, Errors.LP_NFT_IS_NOT_USED_AS_COLLATERAL);

        DataTypes.LoanData memory loanData = ILendPoolLoan(vars.loanAddress)
            .getLoan(vars.loanId);

        DataTypes.ReserveData storage reserveData = reservesData[
            loanData.reserveAsset
        ];
        DataTypes.NftData storage nftData = nftsData[loanData.nftAsset];

        ValidationLogic.validateBuyItNow(
            reserveData,
            nftData,
            loanData,
            params.buyItNowPrice
        );

        // update state MUST BEFORE get borrow amount which is depent on latest borrow index
        reserveData.updateState();

        (
            vars.borrowAmount,
            vars.thresholdPrice,
            vars.liquidatePrice
        ) = GenericLogic.calculateLoanLiquidatePrice(
            vars.loanId,
            loanData.reserveAsset,
            reserveData,
            loanData.nftAsset,
            nftData,
            vars.loanAddress,
            vars.reserveOracle,
            vars.nftOracle
        );

        // first time buy-it-now need to burn debt tokens and transfer reserve to cTokens
        if (loanData.state == DataTypes.LoanState.Active) {
            // loan's accumulated debt must exceed threshold (heath factor below 1.0)
            require(
                vars.borrowAmount > vars.thresholdPrice,
                Errors.LP_BORROW_NOT_EXCEED_LIQUIDATION_THRESHOLD
            );

            // buy price must greater than liquidate price
            require(
                params.buyItNowPrice >= vars.liquidatePrice,
                Errors.LPL_BUYITNOW_PRICE_LESS_THAN_LIQUIDATION_PRICE
            );

            // buy it now sale price must greater than borrow debt
            require(
                params.buyItNowPrice >= vars.borrowAmount,
                Errors.LPL_BUYITNOW_PRICE_LESS_THAN_BORROW
            );
        } else {
            // buy it now sale price must greater than borrow debt
            require(
                params.buyItNowPrice >= vars.borrowAmount,
                Errors.LPL_BUYITNOW_PRICE_LESS_THAN_BORROW
            );

            vars.buyItNowEndTimestamp =
                loanData.buyItNowStartTimestamp +
                (nftData.configuration.getBuyItNowDuration() * 1 days);
            require(
                block.timestamp <= vars.buyItNowEndTimestamp,
                Errors.LPL_BUYITNOW_DURATION_HAS_END
            );

            // buy-it-now price must greater than highest buyItNow + delta
            vars.minBuyItNowDelta = vars.borrowAmount.percentMul(
                PercentageMath.TEN_PERCENT
            );
            require(
                params.buyItNowPrice >=
                    (loanData.buyItNowPrice + vars.minBuyItNowDelta),
                Errors.LPL_BUYITNOW_PRICE_LESS_THAN_HIGHEST_PRICE
            );
        }

        ILendPoolLoan(vars.loanAddress).buyItNowLoan(
            vars.initiator,
            vars.loanId,
            params.onBehalfOf,
            params.buyItNowPrice,
            vars.borrowAmount,
            reserveData.variableBorrowIndex
        );

        // lock buyer price amount to lend pool
        IERC20Upgradeable(loanData.reserveAsset).safeTransferFrom(
            vars.initiator,
            address(this),
            params.buyItNowPrice
        );

        // transfer (return back) last bid price amount to previous bidder from lend pool
        // Can remove this
        // if (loanData.buyItNowBuyerAddress != address(0)) {
        //   IERC20Upgradeable(loanData.reserveAsset).safeTransfer(loanData.buyItNowBuyerAddress, loanData.buyItNowPrice);
        // }

        // update interest rate according latest borrow amount (utilizaton)
        reserveData.updateInterestRates(
            loanData.reserveAsset,
            reserveData.cTokenAddress,
            0,
            0
        );

        emit BuyItNow(
            vars.initiator,
            loanData.reserveAsset,
            params.buyItNowPrice,
            params.nftAsset,
            params.nftTokenId,
            params.onBehalfOf,
            loanData.borrower,
            vars.loanId
        );
        // run executeLiquidate()
    }

    struct RedeemLocalVars {
        address initiator;
        address poolLoan;
        address reserveOracle;
        address nftOracle;
        uint256 loanId;
        uint256 borrowAmount;
        uint256 repayAmount;
        uint256 minRepayAmount;
        uint256 maxRepayAmount;
        uint256 buyItNowFine;
        uint256 redeemEndTimestamp;
        uint256 minBuyItNowFinePct;
        uint256 minBuyItNowFine;
    }

    /**
     * @notice Implements the redeem feature. Through `redeem()`, users redeem assets in the protocol.
     * @dev Emits the `Redeem()` event.
     * @param reservesData The state of all the reserves
     * @param nftsData The state of all the nfts
     * @param params The additional parameters needed to execute the redeem function
     */
    // When is this called?
    // Redeem is called by the original loan borrower to pay back their loan and redeem their nft when the loan is in an auction state (aka buy it now state)
    function executeRedeem(
        ILendPoolAddressesProvider addressesProvider,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(address => DataTypes.NftData) storage nftsData,
        DataTypes.ExecuteRedeemParams memory params
    ) external returns (uint256) {
        RedeemLocalVars memory vars;
        vars.initiator = params.initiator;

        vars.poolLoan = addressesProvider.getLendPoolLoan();
        vars.reserveOracle = addressesProvider.getReserveOracle();
        vars.nftOracle = addressesProvider.getNFTOracle();

        vars.loanId = ILendPoolLoan(vars.poolLoan).getCollateralLoanId(
            params.nftAsset,
            params.nftTokenId
        );
        require(vars.loanId != 0, Errors.LP_NFT_IS_NOT_USED_AS_COLLATERAL);

        DataTypes.LoanData memory loanData = ILendPoolLoan(vars.poolLoan)
            .getLoan(vars.loanId);

        DataTypes.ReserveData storage reserveData = reservesData[
            loanData.reserveAsset
        ];
        DataTypes.NftData storage nftData = nftsData[loanData.nftAsset];

        ValidationLogic.validateRedeem(
            reserveData,
            nftData,
            loanData,
            params.amount
        );

        vars.redeemEndTimestamp = (loanData.buyItNowStartTimestamp +
            nftData.configuration.getRedeemDuration() *
            1 days);
        require(
            block.timestamp <= vars.redeemEndTimestamp,
            Errors.LPL_BUYITNOW_REDEEM_DURATION_HAS_END
        );

        // update state MUST BEFORE get borrow amount which is depent on latest borrow index
        reserveData.updateState();

        (vars.borrowAmount, , ) = GenericLogic.calculateLoanLiquidatePrice(
            vars.loanId,
            loanData.reserveAsset,
            reserveData,
            loanData.nftAsset,
            nftData,
            vars.poolLoan,
            vars.reserveOracle,
            vars.nftOracle
        );

        // check buy-it-now fine in min & max range
        (, vars.buyItNowFine) = GenericLogic.calculateLoanBuyItNowFine(
            loanData.reserveAsset,
            reserveData,
            loanData.nftAsset,
            nftData,
            loanData,
            vars.poolLoan,
            vars.reserveOracle
        );

        // check buy-it-now fine is enough
        require(
            vars.buyItNowFine <= params.buyItNowFine,
            Errors.LPL_INVALID_BUYITNOW_FINE
        );

        // check the minimum debt repay amount, use redeem threshold in config
        vars.repayAmount = params.amount;
        vars.minRepayAmount = vars.borrowAmount.percentMul(
            nftData.configuration.getRedeemThreshold()
        );
        require(
            vars.repayAmount >= vars.minRepayAmount,
            Errors.LP_AMOUNT_LESS_THAN_REDEEM_THRESHOLD
        );

        // check the maxinmum debt repay amount, 90%?
        // TODO: Need to understand this more
        vars.maxRepayAmount = vars.borrowAmount.percentMul(
            PercentageMath.PERCENTAGE_FACTOR - PercentageMath.TEN_PERCENT
        );
        require(
            vars.repayAmount <= vars.maxRepayAmount,
            Errors.LP_AMOUNT_GREATER_THAN_MAX_REPAY
        );

        ILendPoolLoan(vars.poolLoan).redeemLoan(
            vars.initiator,
            vars.loanId,
            vars.repayAmount,
            reserveData.variableBorrowIndex
        );

        IDebtToken(reserveData.debtTokenAddress).burn(
            loanData.borrower,
            vars.repayAmount,
            reserveData.variableBorrowIndex
        );

        // update interest rate according latest borrow amount (utilizaton)
        reserveData.updateInterestRates(
            loanData.reserveAsset,
            reserveData.cTokenAddress,
            vars.repayAmount,
            0
        );

        // transfer repay amount from borrower to cToken
        IERC20Upgradeable(loanData.reserveAsset).safeTransferFrom(
            vars.initiator,
            reserveData.cTokenAddress,
            vars.repayAmount
        );

        // Can Delete this but will need to update test case
        if (loanData.buyItNowBuyerAddress != address(0)) {
            // transfer (return back) last buy-it-now price amount from lend pool to buy-it-now buyer
            IERC20Upgradeable(loanData.reserveAsset).safeTransfer(
                loanData.buyItNowBuyerAddress,
                loanData.buyItNowPrice
            );

            // transfer buy-it-now penalty fine amount from borrower to the buy-it-now buyer
            IERC20Upgradeable(loanData.reserveAsset).safeTransferFrom(
                vars.initiator,
                loanData.buyItNowBuyerAddress,
                vars.buyItNowFine
            );
        }

        emit Redeem(
            vars.initiator,
            loanData.reserveAsset,
            vars.repayAmount,
            vars.buyItNowFine,
            loanData.nftAsset,
            loanData.nftTokenId,
            loanData.borrower,
            vars.loanId
        );

        return (vars.repayAmount + vars.buyItNowFine);
    }

    struct LiquidateLocalVars {
        address initiator;
        address poolLoan;
        address reserveOracle;
        address nftOracle;
        uint256 loanId;
        uint256 borrowAmount;
        uint256 extraDebtAmount;
        uint256 remainAmount;
        uint256 buyItNowEndTimestamp;
    }

    /**
     * @notice Implements the liquidate feature. Through `liquidate()`, users liquidate assets in the protocol.
     * @dev Emits the `Liquidate()` event.
     * @param reservesData The state of all the reserves
     * @param nftsData The state of all the nfts
     * @param params The additional parameters needed to execute the liquidate function
     */
    function executeLiquidate(
        ILendPoolAddressesProvider addressesProvider,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(address => DataTypes.NftData) storage nftsData,
        DataTypes.ExecuteLiquidateParams memory params
    ) external returns (uint256) {
        LiquidateLocalVars memory vars;
        vars.initiator = params.initiator;

        vars.poolLoan = addressesProvider.getLendPoolLoan();
        vars.reserveOracle = addressesProvider.getReserveOracle();
        vars.nftOracle = addressesProvider.getNFTOracle();

        vars.loanId = ILendPoolLoan(vars.poolLoan).getCollateralLoanId(
            params.nftAsset,
            params.nftTokenId
        );
        require(vars.loanId != 0, Errors.LP_NFT_IS_NOT_USED_AS_COLLATERAL);

        DataTypes.LoanData memory loanData = ILendPoolLoan(vars.poolLoan)
            .getLoan(vars.loanId);

        DataTypes.ReserveData storage reserveData = reservesData[
            loanData.reserveAsset
        ];
        DataTypes.NftData storage nftData = nftsData[loanData.nftAsset];

        ValidationLogic.validateLiquidate(reserveData, nftData, loanData);

        // Can remove. We can liquidate before the auction duration has completed.
        // vars.buyItNowEndTimestamp = loanData.buyItNowStartTimestamp + (nftData.configuration.getBuyItNowDuration() * 1 days);
        // vars.buyItNowEndTimestamp = loanData.buyItNowStartTimestamp;
        // require that buy-it-now has started
        require(
            block.timestamp > loanData.buyItNowStartTimestamp,
            Errors.LPL_BUYITNOW_DURATION_NOT_START
        );

        // update state MUST BEFORE get borrow amount which is depent on latest borrow index
        reserveData.updateState();

        (vars.borrowAmount, , ) = GenericLogic.calculateLoanLiquidatePrice(
            vars.loanId,
            loanData.reserveAsset,
            reserveData,
            loanData.nftAsset,
            nftData,
            vars.poolLoan,
            vars.reserveOracle,
            vars.nftOracle
        );

        // buyItNow price can not cover borrow amount
        if (loanData.buyItNowPrice < vars.borrowAmount) {
            vars.extraDebtAmount = vars.borrowAmount - loanData.buyItNowPrice;
            require(
                params.amount >= vars.extraDebtAmount,
                Errors.LP_AMOUNT_LESS_THAN_EXTRA_DEBT
            );
        }

        if (loanData.buyItNowPrice > vars.borrowAmount) {
            vars.remainAmount = loanData.buyItNowPrice - vars.borrowAmount;
        }

        // where is loanData.buyItNowBuyerAddress set?
        ILendPoolLoan(vars.poolLoan).liquidateLoan(
            loanData.buyItNowBuyerAddress,
            vars.loanId,
            nftData.cNFTAddress,
            vars.borrowAmount,
            reserveData.variableBorrowIndex
        );

        IDebtToken(reserveData.debtTokenAddress).burn(
            loanData.borrower,
            vars.borrowAmount,
            reserveData.variableBorrowIndex
        );

        // update interest rate according latest borrow amount (utilizaton)
        reserveData.updateInterestRates(
            loanData.reserveAsset,
            reserveData.cTokenAddress,
            vars.borrowAmount,
            0
        );

        // transfer extra borrow amount from liquidator to lend pool
        if (vars.extraDebtAmount > 0) {
            IERC20Upgradeable(loanData.reserveAsset).safeTransferFrom(
                vars.initiator,
                address(this),
                vars.extraDebtAmount
            );
        }

        // transfer borrow amount from lend pool to cToken, repay debt
        IERC20Upgradeable(loanData.reserveAsset).safeTransfer(
            reserveData.cTokenAddress,
            vars.borrowAmount
        );

        // transfer remain amount to borrower
        if (vars.remainAmount > 0) {
            IERC20Upgradeable(loanData.reserveAsset).safeTransfer(
                loanData.borrower,
                vars.remainAmount
            );
        }

        // transfer erc721 to buy-it-now buyer
        IERC721Upgradeable(loanData.nftAsset).safeTransferFrom(
            address(this),
            loanData.buyItNowBuyerAddress,
            params.nftTokenId
        );

        emit Liquidate(
            vars.initiator,
            loanData.reserveAsset,
            vars.borrowAmount,
            vars.remainAmount,
            loanData.nftAsset,
            loanData.nftTokenId,
            loanData.borrower,
            vars.loanId
        );

        return (vars.extraDebtAmount);
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title ReserveConfiguration library
 * @author Confetti
 * @notice Implements the bitmap logic to handle the reserve configuration
 */
library ReserveConfiguration {
  uint256 constant LTV_MASK =                   0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
  uint256 constant LIQUIDATION_THRESHOLD_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
  uint256 constant LIQUIDATION_BONUS_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
  uint256 constant DECIMALS_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
  uint256 constant ACTIVE_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
  uint256 constant FROZEN_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
  uint256 constant BORROWING_MASK =             0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
  uint256 constant STABLE_BORROWING_MASK =      0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFF; // prettier-ignore
  uint256 constant RESERVE_FACTOR_MASK =        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF; // prettier-ignore

  /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
  uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
  uint256 constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
  uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
  uint256 constant IS_ACTIVE_START_BIT_POSITION = 56;
  uint256 constant IS_FROZEN_START_BIT_POSITION = 57;
  uint256 constant BORROWING_ENABLED_START_BIT_POSITION = 58;
  uint256 constant STABLE_BORROWING_ENABLED_START_BIT_POSITION = 59;
  uint256 constant RESERVE_FACTOR_START_BIT_POSITION = 64;

  uint256 constant MAX_VALID_LTV = 65535;
  uint256 constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
  uint256 constant MAX_VALID_LIQUIDATION_BONUS = 65535;
  uint256 constant MAX_VALID_DECIMALS = 255;
  uint256 constant MAX_VALID_RESERVE_FACTOR = 65535;

  /**
   * @dev Sets the Loan to Value of the reserve
   * @param self The reserve configuration
   * @param ltv the new ltv
   **/
  function setLtv(DataTypes.ReserveConfigurationMap memory self, uint256 ltv) internal pure {
    require(ltv <= MAX_VALID_LTV, Errors.RC_INVALID_LTV);

    self.data = (self.data & LTV_MASK) | ltv;
  }

  /**
   * @dev Gets the Loan to Value of the reserve
   * @param self The reserve configuration
   * @return The loan to value
   **/
  function getLtv(DataTypes.ReserveConfigurationMap storage self) internal view returns (uint256) {
    return self.data & ~LTV_MASK;
  }

  /**
   * @dev Sets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @param threshold The new liquidation threshold
   **/
  function setLiquidationThreshold(DataTypes.ReserveConfigurationMap memory self, uint256 threshold) internal pure {
    require(threshold <= MAX_VALID_LIQUIDATION_THRESHOLD, Errors.RC_INVALID_LIQ_THRESHOLD);

    self.data = (self.data & LIQUIDATION_THRESHOLD_MASK) | (threshold << LIQUIDATION_THRESHOLD_START_BIT_POSITION);
  }

  /**
   * @dev Gets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @return The liquidation threshold
   **/
  function getLiquidationThreshold(DataTypes.ReserveConfigurationMap storage self) internal view returns (uint256) {
    return (self.data & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
  }

  /**
   * @dev Sets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @param bonus The new liquidation bonus
   **/
  function setLiquidationBonus(DataTypes.ReserveConfigurationMap memory self, uint256 bonus) internal pure {
    require(bonus <= MAX_VALID_LIQUIDATION_BONUS, Errors.RC_INVALID_LIQ_BONUS);

    self.data = (self.data & LIQUIDATION_BONUS_MASK) | (bonus << LIQUIDATION_BONUS_START_BIT_POSITION);
  }

  /**
   * @dev Gets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @return The liquidation bonus
   **/
  function getLiquidationBonus(DataTypes.ReserveConfigurationMap storage self) internal view returns (uint256) {
    return (self.data & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION;
  }

  /**
   * @dev Sets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @param decimals The decimals
   **/
  function setDecimals(DataTypes.ReserveConfigurationMap memory self, uint256 decimals) internal pure {
    require(decimals <= MAX_VALID_DECIMALS, Errors.RC_INVALID_DECIMALS);

    self.data = (self.data & DECIMALS_MASK) | (decimals << RESERVE_DECIMALS_START_BIT_POSITION);
  }

  /**
   * @dev Gets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @return The decimals of the asset
   **/
  function getDecimals(DataTypes.ReserveConfigurationMap storage self) internal view returns (uint256) {
    return (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
  }

  /**
   * @dev Sets the active state of the reserve
   * @param self The reserve configuration
   * @param active The active state
   **/
  function setActive(DataTypes.ReserveConfigurationMap memory self, bool active) internal pure {
    self.data = (self.data & ACTIVE_MASK) | (uint256(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
  }

  /**
   * @dev Gets the active state of the reserve
   * @param self The reserve configuration
   * @return The active state
   **/
  function getActive(DataTypes.ReserveConfigurationMap storage self) internal view returns (bool) {
    return (self.data & ~ACTIVE_MASK) != 0;
  }

  /**
   * @dev Sets the frozen state of the reserve
   * @param self The reserve configuration
   * @param frozen The frozen state
   **/
  function setFrozen(DataTypes.ReserveConfigurationMap memory self, bool frozen) internal pure {
    self.data = (self.data & FROZEN_MASK) | (uint256(frozen ? 1 : 0) << IS_FROZEN_START_BIT_POSITION);
  }

  /**
   * @dev Gets the frozen state of the reserve
   * @param self The reserve configuration
   * @return The frozen state
   **/
  function getFrozen(DataTypes.ReserveConfigurationMap storage self) internal view returns (bool) {
    return (self.data & ~FROZEN_MASK) != 0;
  }

  /**
   * @dev Enables or disables borrowing on the reserve
   * @param self The reserve configuration
   * @param enabled True if the borrowing needs to be enabled, false otherwise
   **/
  function setBorrowingEnabled(DataTypes.ReserveConfigurationMap memory self, bool enabled) internal pure {
    self.data = (self.data & BORROWING_MASK) | (uint256(enabled ? 1 : 0) << BORROWING_ENABLED_START_BIT_POSITION);
  }

  /**
   * @dev Gets the borrowing state of the reserve
   * @param self The reserve configuration
   * @return The borrowing state
   **/
  function getBorrowingEnabled(DataTypes.ReserveConfigurationMap storage self) internal view returns (bool) {
    return (self.data & ~BORROWING_MASK) != 0;
  }

  /**
   * @dev Enables or disables stable rate borrowing on the reserve
   * @param self The reserve configuration
   * @param enabled True if the stable rate borrowing needs to be enabled, false otherwise
   **/
  function setStableRateBorrowingEnabled(DataTypes.ReserveConfigurationMap memory self, bool enabled) internal pure {
    self.data =
      (self.data & STABLE_BORROWING_MASK) |
      (uint256(enabled ? 1 : 0) << STABLE_BORROWING_ENABLED_START_BIT_POSITION);
  }

  /**
   * @dev Gets the stable rate borrowing state of the reserve
   * @param self The reserve configuration
   * @return The stable rate borrowing state
   **/
  function getStableRateBorrowingEnabled(DataTypes.ReserveConfigurationMap storage self) internal view returns (bool) {
    return (self.data & ~STABLE_BORROWING_MASK) != 0;
  }

  /**
   * @dev Sets the reserve factor of the reserve
   * @param self The reserve configuration
   * @param reserveFactor The reserve factor
   **/
  function setReserveFactor(DataTypes.ReserveConfigurationMap memory self, uint256 reserveFactor) internal pure {
    require(reserveFactor <= MAX_VALID_RESERVE_FACTOR, Errors.RC_INVALID_RESERVE_FACTOR);

    self.data = (self.data & RESERVE_FACTOR_MASK) | (reserveFactor << RESERVE_FACTOR_START_BIT_POSITION);
  }

  /**
   * @dev Gets the reserve factor of the reserve
   * @param self The reserve configuration
   * @return The reserve factor
   **/
  function getReserveFactor(DataTypes.ReserveConfigurationMap storage self) internal view returns (uint256) {
    return (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
  }

  /**
   * @dev Gets the configuration flags of the reserve
   * @param self The reserve configuration
   * @return The state flags representing active, frozen, borrowing enabled, stableRateBorrowing enabled
   **/
  function getFlags(DataTypes.ReserveConfigurationMap storage self)
    internal
    view
    returns (
      bool,
      bool,
      bool,
      bool
    )
  {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & ~ACTIVE_MASK) != 0,
      (dataLocal & ~FROZEN_MASK) != 0,
      (dataLocal & ~BORROWING_MASK) != 0,
      (dataLocal & ~STABLE_BORROWING_MASK) != 0
    );
  }

  /**
   * @dev Gets the configuration paramters of the reserve
   * @param self The reserve configuration
   * @return The state params representing ltv, liquidation threshold, liquidation bonus, the reserve decimals
   **/
  function getParams(DataTypes.ReserveConfigurationMap storage self)
    internal
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    uint256 dataLocal = self.data;

    return (
      dataLocal & ~LTV_MASK,
      (dataLocal & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
      (dataLocal & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
      (dataLocal & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
      (dataLocal & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
    );
  }

  /**
   * @dev Gets the configuration paramters of the reserve from a memory object
   * @param self The reserve configuration
   * @return The state params representing ltv, liquidation threshold, liquidation bonus, the reserve decimals
   **/
  function getParamsMemory(DataTypes.ReserveConfigurationMap memory self)
    internal
    pure
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      self.data & ~LTV_MASK,
      (self.data & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
      (self.data & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
      (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
      (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
    );
  }

  /**
   * @dev Gets the configuration flags of the reserve from a memory object
   * @param self The reserve configuration
   * @return The state flags representing active, frozen, borrowing enabled, stableRateBorrowing enabled
   **/
  function getFlagsMemory(DataTypes.ReserveConfigurationMap memory self)
    internal
    pure
    returns (
      bool,
      bool,
      bool,
      bool
    )
  {
    return (
      (self.data & ~ACTIVE_MASK) != 0,
      (self.data & ~FROZEN_MASK) != 0,
      (self.data & ~BORROWING_MASK) != 0,
      (self.data & ~STABLE_BORROWING_MASK) != 0
    );
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title NftConfiguration library
 * @author Confetti
 * @notice Implements the bitmap logic to handle the NFT configuration
 */
library NftConfiguration {
    uint256 constant LTV_MASK =                   0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
    uint256 constant LIQUIDATION_THRESHOLD_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
    uint256 constant LIQUIDATION_BONUS_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
    uint256 constant ACTIVE_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant FROZEN_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant REDEEM_DURATION_MASK =       0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant BUYITNOW_DURATION_MASK =      0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant REDEEM_FINE_MASK =           0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant REDEEM_THRESHOLD_MASK =      0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant MIN_BUYITNOWFINE_MASK      =      0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

    /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
    uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 constant IS_ACTIVE_START_BIT_POSITION = 56;
    uint256 constant IS_FROZEN_START_BIT_POSITION = 57;
    uint256 constant REDEEM_DURATION_START_BIT_POSITION = 64;
    uint256 constant BUYITNOW_DURATION_START_BIT_POSITION = 72;
    uint256 constant REDEEM_FINE_START_BIT_POSITION = 80;
    uint256 constant REDEEM_THRESHOLD_START_BIT_POSITION = 96;
    uint256 constant MIN_BUYITNOWFINE_START_BIT_POSITION = 112;

    uint256 constant MAX_VALID_LTV = 65535;
    uint256 constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
    uint256 constant MAX_VALID_LIQUIDATION_BONUS = 65535;
    uint256 constant MAX_VALID_REDEEM_DURATION = 255;
    uint256 constant MAX_VALID_BUYITNOW_DURATION = 255;
    uint256 constant MAX_VALID_REDEEM_FINE = 65535;
    uint256 constant MAX_VALID_REDEEM_THRESHOLD = 65535;
    uint256 constant MAX_VALID_MIN_BUYITNOWFINE = 65535;

    /**
     * @dev Sets the Loan to Value of the NFT
     * @param self The NFT configuration
     * @param ltv the new ltv
     **/
    function setLtv(DataTypes.NftConfigurationMap memory self, uint256 ltv)
        internal
        pure
    {
        require(ltv <= MAX_VALID_LTV, Errors.RC_INVALID_LTV);

        self.data = (self.data & LTV_MASK) | ltv;
    }

    /**
     * @dev Gets the Loan to Value of the NFT
     * @param self The NFT configuration
     * @return The loan to value
     **/
    function getLtv(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return self.data & ~LTV_MASK;
    }

    /**
     * @dev Sets the liquidation threshold of the NFT
     * @param self The NFT configuration
     * @param threshold The new liquidation threshold
     **/
    function setLiquidationThreshold(
        DataTypes.NftConfigurationMap memory self,
        uint256 threshold
    ) internal pure {
        require(
            threshold <= MAX_VALID_LIQUIDATION_THRESHOLD,
            Errors.RC_INVALID_LIQ_THRESHOLD
        );

        self.data =
            (self.data & LIQUIDATION_THRESHOLD_MASK) |
            (threshold << LIQUIDATION_THRESHOLD_START_BIT_POSITION);
    }

    /**
     * @dev Gets the liquidation threshold of the NFT
     * @param self The NFT configuration
     * @return The liquidation threshold
     **/
    function getLiquidationThreshold(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~LIQUIDATION_THRESHOLD_MASK) >>
            LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    /**
     * @dev Sets the liquidation bonus of the NFT
     * @param self The NFT configuration
     * @param bonus The new liquidation bonus
     **/
    function setLiquidationBonus(
        DataTypes.NftConfigurationMap memory self,
        uint256 bonus
    ) internal pure {
        require(
            bonus <= MAX_VALID_LIQUIDATION_BONUS,
            Errors.RC_INVALID_LIQ_BONUS
        );

        self.data =
            (self.data & LIQUIDATION_BONUS_MASK) |
            (bonus << LIQUIDATION_BONUS_START_BIT_POSITION);
    }

    /**
     * @dev Gets the liquidation bonus of the NFT
     * @param self The NFT configuration
     * @return The liquidation bonus
     **/
    function getLiquidationBonus(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~LIQUIDATION_BONUS_MASK) >>
            LIQUIDATION_BONUS_START_BIT_POSITION;
    }

    /**
     * @dev Sets the active state of the NFT
     * @param self The NFT configuration
     * @param active The active state
     **/
    function setActive(DataTypes.NftConfigurationMap memory self, bool active)
        internal
        pure
    {
        self.data =
            (self.data & ACTIVE_MASK) |
            (uint256(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
    }

    /**
     * @dev Gets the active state of the NFT
     * @param self The NFT configuration
     * @return The active state
     **/
    function getActive(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (bool)
    {
        return (self.data & ~ACTIVE_MASK) != 0;
    }

    /**
     * @dev Sets the frozen state of the NFT
     * @param self The NFT configuration
     * @param frozen The frozen state
     **/
    function setFrozen(DataTypes.NftConfigurationMap memory self, bool frozen)
        internal
        pure
    {
        self.data =
            (self.data & FROZEN_MASK) |
            (uint256(frozen ? 1 : 0) << IS_FROZEN_START_BIT_POSITION);
    }

    /**
     * @dev Gets the frozen state of the NFT
     * @param self The NFT configuration
     * @return The frozen state
     **/
    function getFrozen(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (bool)
    {
        return (self.data & ~FROZEN_MASK) != 0;
    }

    /**
     * @dev Sets the redeem duration of the NFT
     * @param self The NFT configuration
     * @param redeemDuration The redeem duration
     **/
    function setRedeemDuration(
        DataTypes.NftConfigurationMap memory self,
        uint256 redeemDuration
    ) internal pure {
        require(
            redeemDuration <= MAX_VALID_REDEEM_DURATION,
            Errors.RC_INVALID_REDEEM_DURATION
        );

        self.data =
            (self.data & REDEEM_DURATION_MASK) |
            (redeemDuration << REDEEM_DURATION_START_BIT_POSITION);
    }

    /**
     * @dev Gets the redeem duration of the NFT
     * @param self The NFT configuration
     * @return The redeem duration
     **/
    function getRedeemDuration(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~REDEEM_DURATION_MASK) >>
            REDEEM_DURATION_START_BIT_POSITION;
    }

    /**
     * @dev Sets the buyItNow duration of the NFT
     * @param self The NFT configuration
     * @param buyItNowDuration The buy-it-now duration
     **/
    function setBuyItNowDuration(
        DataTypes.NftConfigurationMap memory self,
        uint256 buyItNowDuration
    ) internal pure {
        require(
            buyItNowDuration <= MAX_VALID_BUYITNOW_DURATION,
            Errors.RC_INVALID_BUYITNOW_DURATION
        );

        self.data =
            (self.data & BUYITNOW_DURATION_MASK) |
            (buyItNowDuration << BUYITNOW_DURATION_START_BIT_POSITION);
    }

    /**
     * @dev Gets the buy-it-now duration of the NFT
     * @param self The NFT configuration
     * @return The buy-it-now duration
     **/
    function getBuyItNowDuration(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~BUYITNOW_DURATION_MASK) >>
            BUYITNOW_DURATION_START_BIT_POSITION;
    }

    /**
     * @dev Sets the redeem fine of the NFT
     * @param self The NFT configuration
     * @param redeemFine The redeem duration
     **/
    function setRedeemFine(
        DataTypes.NftConfigurationMap memory self,
        uint256 redeemFine
    ) internal pure {
        require(
            redeemFine <= MAX_VALID_REDEEM_FINE,
            Errors.RC_INVALID_REDEEM_FINE
        );

        self.data =
            (self.data & REDEEM_FINE_MASK) |
            (redeemFine << REDEEM_FINE_START_BIT_POSITION);
    }

    /**
     * @dev Gets the redeem fine of the NFT
     * @param self The NFT configuration
     * @return The redeem fine
     **/
    function getRedeemFine(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~REDEEM_FINE_MASK) >> REDEEM_FINE_START_BIT_POSITION;
    }

    /**
     * @dev Sets the redeem threshold of the NFT
     * @param self The NFT configuration
     * @param redeemThreshold The redeem duration
     **/
    function setRedeemThreshold(
        DataTypes.NftConfigurationMap memory self,
        uint256 redeemThreshold
    ) internal pure {
        require(
            redeemThreshold <= MAX_VALID_REDEEM_THRESHOLD,
            Errors.RC_INVALID_REDEEM_THRESHOLD
        );

        self.data =
            (self.data & REDEEM_THRESHOLD_MASK) |
            (redeemThreshold << REDEEM_THRESHOLD_START_BIT_POSITION);
    }

    /**
     * @dev Gets the redeem threshold of the NFT
     * @param self The NFT configuration
     * @return The redeem threshold
     **/
    function getRedeemThreshold(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return
            (self.data & ~REDEEM_THRESHOLD_MASK) >>
            REDEEM_THRESHOLD_START_BIT_POSITION;
    }

    /**
     * @dev Sets the min & max threshold of the NFT
     * @param self The NFT configuration
     * @param minBuyItNowFine The min buy-it-now fine
     **/
    function setMinBuyItNowFine(
        DataTypes.NftConfigurationMap memory self,
        uint256 minBuyItNowFine
    ) internal pure {
        require(
            minBuyItNowFine <= MAX_VALID_MIN_BUYITNOWFINE,
            Errors.RC_INVALID_MIN_BUYITNOW_FINE
        );

        self.data =
            (self.data & MIN_BUYITNOWFINE_MASK) |
            (minBuyItNowFine << MIN_BUYITNOWFINE_START_BIT_POSITION);
    }

    /**
     * @dev Gets the min buy-it-now fine of the NFT
     * @param self The NFT configuration
     * @return The min buy-it-now fine
     **/
    function getMinBuyItNowFine(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (uint256)
    {
        return ((self.data & ~MIN_BUYITNOWFINE_MASK) >>
            MIN_BUYITNOWFINE_START_BIT_POSITION);
    }

    /**
     * @dev Gets the configuration flags of the NFT
     * @param self The NFT configuration
     * @return The state flags representing active, frozen
     **/
    function getFlags(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (bool, bool)
    {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & ~ACTIVE_MASK) != 0,
            (dataLocal & ~FROZEN_MASK) != 0
        );
    }

    /**
     * @dev Gets the configuration flags of the NFT from a memory object
     * @param self The NFT configuration
     * @return The state flags representing active, frozen
     **/
    function getFlagsMemory(DataTypes.NftConfigurationMap memory self)
        internal
        pure
        returns (bool, bool)
    {
        return (
            (self.data & ~ACTIVE_MASK) != 0,
            (self.data & ~FROZEN_MASK) != 0
        );
    }

    /**
     * @dev Gets the collateral configuration paramters of the NFT
     * @param self The NFT configuration
     * @return The state params representing ltv, liquidation threshold, liquidation bonus
     **/
    function getCollateralParams(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 dataLocal = self.data;

        return (
            dataLocal & ~LTV_MASK,
            (dataLocal & ~LIQUIDATION_THRESHOLD_MASK) >>
                LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (dataLocal & ~LIQUIDATION_BONUS_MASK) >>
                LIQUIDATION_BONUS_START_BIT_POSITION
        );
    }

    /**
     * @dev Gets the buy-it-now configuration paramters of the NFT
     * @param self The NFT configuration
     * @return The state params representing redeem duration, buy-it-now duration, redeem fine
     **/
    function getBuyItNowParams(DataTypes.NftConfigurationMap storage self)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & ~REDEEM_DURATION_MASK) >>
                REDEEM_DURATION_START_BIT_POSITION,
            (dataLocal & ~BUYITNOW_DURATION_MASK) >>
                BUYITNOW_DURATION_START_BIT_POSITION,
            (dataLocal & ~REDEEM_FINE_MASK) >> REDEEM_FINE_START_BIT_POSITION,
            (dataLocal & ~REDEEM_THRESHOLD_MASK) >>
                REDEEM_THRESHOLD_START_BIT_POSITION
        );
    }

    /**
     * @dev Gets the collateral configuration paramters of the NFT from a memory object
     * @param self The NFT configuration
     * @return The state params representing ltv, liquidation threshold, liquidation bonus
     **/
    function getCollateralParamsMemory(
        DataTypes.NftConfigurationMap memory self
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            self.data & ~LTV_MASK,
            (self.data & ~LIQUIDATION_THRESHOLD_MASK) >>
                LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (self.data & ~LIQUIDATION_BONUS_MASK) >>
                LIQUIDATION_BONUS_START_BIT_POSITION
        );
    }

    /**
     * @dev Gets the buy-it-now configuration paramters of the NFT from a memory object
     * @param self The NFT configuration
     * @return The state params representing redeem duration, buy-it-now duration, redeem fine
     **/
    function getBuyItNowParamsMemory(DataTypes.NftConfigurationMap memory self)
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            (self.data & ~REDEEM_DURATION_MASK) >>
                REDEEM_DURATION_START_BIT_POSITION,
            (self.data & ~BUYITNOW_DURATION_MASK) >>
                BUYITNOW_DURATION_START_BIT_POSITION,
            (self.data & ~REDEEM_FINE_MASK) >> REDEEM_FINE_START_BIT_POSITION,
            (self.data & ~REDEEM_THRESHOLD_MASK) >>
                REDEEM_THRESHOLD_START_BIT_POSITION
        );
    }

    /**
     * @dev Gets the min & max buy-it-now fine of the NFT
     * @param self The NFT configuration
     * @return The min & max buy-it-now fine
     **/
    function getMinBuyItNowFineMemory(DataTypes.NftConfigurationMap memory self)
        internal
        pure
        returns (uint256)
    {
        return ((self.data & ~MIN_BUYITNOWFINE_MASK) >>
            MIN_BUYITNOWFINE_START_BIT_POSITION);
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

library DataTypes {
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        uint40 lastUpdateTimestamp;
        //tokens addresses
        address cTokenAddress;
        address debtTokenAddress;
        //address of the interest rate strategy
        address interestRateAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    struct NftData {
        //stores the nft configuration
        NftConfigurationMap configuration;
        //address of the cNFT contract
        address cNFTAddress;
        //the id of the nft. Represents the position in the list of the active nfts
        uint8 id;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60-63: reserved
        //bit 64-79: reserve factor
        uint256 data;
    }

    struct NftConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 56: NFT is active
        //bit 57: NFT is frozen
        uint256 data;
    }

    /**
     * @dev Enum describing the current state of a loan
     * State change flow:
     *  Created -> Active -> Repaid
     *                    -> BuyItNow -> Defaulted
     */
    enum LoanState {
        // We need a default that is not 'Created' - this is the zero value
        None,
        // The loan data is stored, but not initiated yet.
        Created,
        // The loan has been initialized, funds have been delivered to the borrower and the collateral is held.
        Active,
        // The loan is in buy-it-now, higest price liquidator will got chance to claim it.
        BuyItNow,
        // The loan has been repaid, and the collateral has been returned to the borrower. This is a terminal state.
        Repaid,
        // The loan was delinquent and collateral claimed by the liquidator. This is a terminal state.
        Defaulted
    }

    struct LoanData {
        //the id of the nft loan
        uint256 loanId;
        //the current state of the loan
        LoanState state;
        //address of borrower
        address borrower;
        //address of nft asset token
        address nftAsset;
        //the id of nft token
        uint256 nftTokenId;
        //address of reserve asset token
        address reserveAsset;
        //scaled borrow amount. Expressed in ray
        uint256 scaledAmount;
        //start time of first buyItNowBuyer time
        uint256 buyItNowStartTimestamp;
        //buyItNowBuyer address of higest buy-it-now price - TODO: Can likely remove
        address buyItNowBuyerAddress;
        //buy-it-now price
        uint256 buyItNowPrice;
        //borrow amount of loan
        uint256 buyItNowBorrowAmount;
        //buyItNowBuyer address of first buy-it-now - TODO: rename this
        // address firstBuyItNowBuyerAddress;
    }

    struct ExecuteDepositParams {
        address initiator;
        address asset;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct ExecuteWithdrawParams {
        address initiator;
        address asset;
        uint256 amount;
        address to;
    }

    struct ExecuteBorrowParams {
        address initiator;
        address asset;
        uint256 amount;
        address nftAsset;
        uint256 nftTokenId;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct ExecuteBatchBorrowParams {
        address initiator;
        address[] assets;
        uint256[] amounts;
        address[] nftAssets;
        uint256[] nftTokenIds;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct ExecuteRepayParams {
        address initiator;
        address nftAsset;
        uint256 nftTokenId;
        uint256 amount;
    }

    struct ExecuteBatchRepayParams {
        address initiator;
        address[] nftAssets;
        uint256[] nftTokenIds;
        uint256[] amounts;
    }

    struct ExecuteBuyItNowParams {
        address initiator;
        address nftAsset;
        uint256 nftTokenId;
        uint256 buyItNowPrice;
        address onBehalfOf;
    }

    struct ExecuteRedeemParams {
        address initiator;
        address nftAsset;
        uint256 nftTokenId;
        uint256 amount;
        uint256 buyItNowFine;
    }

    struct ExecuteLiquidateParams {
        address initiator;
        address nftAsset;
        uint256 nftTokenId;
        uint256 amount;
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {DataTypes} from "../libraries/types/DataTypes.sol";
import {ReserveLogic} from "../libraries/logic/ReserveLogic.sol";
import {NftLogic} from "../libraries/logic/NftLogic.sol";
import {ILendPoolAddressesProvider} from "../interfaces/ILendPoolAddressesProvider.sol";

contract LendPoolStorage {
  using ReserveLogic for DataTypes.ReserveData;
  using NftLogic for DataTypes.NftData;

  ILendPoolAddressesProvider internal _addressesProvider;

  mapping(address => DataTypes.ReserveData) internal _reserves;
  mapping(address => DataTypes.NftData) internal _nfts;

  mapping(uint256 => address) internal _reservesList;
  uint256 internal _reservesCount;

  mapping(uint256 => address) internal _nftsList;
  uint256 internal _nftsCount;

  bool internal _paused;

  uint256 internal _maxNumberOfReserves;
  uint256 internal _maxNumberOfNfts;

  // !!! Never add new variable at here, because this contract is inherited by LendPool !!!
  // !!! Add new variable at LendPool directly !!!
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

contract LendPoolStorageExt {
  // !!! Add new variable MUST append it only, do not insert, update type & name, or change order !!!
  // https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#potentially-unsafe-operations

  uint256 internal constant _NOT_ENTERED = 0;
  uint256 internal constant _ENTERED = 1;
  uint256 internal _status;

  // For upgradable, add one new variable above, minus 1 at here
  uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
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
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

/************
@title IReserveOracleGetter interface
@notice Interface for getting Reserve price oracle.*/
interface IReserveOracleGetter {
  /* CAUTION: Price uint is ETH based (WEI, 18 decimals) */
  /***********
    @dev returns the asset price in ETH
     */
  function getAssetPrice(address asset) external view returns (uint256);

  // get twap price depending on _period
  function getTwapPrice(address _priceFeedKey, uint256 _interval) external view returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

/************
@title INFTOracleGetter interface
@notice Interface for getting NFT price oracle.*/
interface INFTOracleGetter {
  /* CAUTION: Price uint is ETH based (WEI, 18 decimals) */
  /***********
    @dev returns the asset price in ETH
     */
  function getAssetPrice(address asset) external view returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ILendPoolAddressesProvider} from "./ILendPoolAddressesProvider.sol";
import {IIncentivesController} from "./IIncentivesController.sol";
import {IScaledBalanceToken} from "./IScaledBalanceToken.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface ICToken is IScaledBalanceToken, IERC20Upgradeable, IERC20MetadataUpgradeable {
  /**
   * @dev Emitted when an cToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated lending pool
   * @param treasury The address of the treasury
   * @param incentivesController The address of the incentives controller for this cToken
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address treasury,
    address incentivesController
  );

  /**
   * @dev Initializes the cToken
   * @param addressProvider The address of the address provider where this cToken will be used
   * @param treasury The address of the Confetti treasury, receiving the fees on this cToken
   * @param underlyingAsset The address of the underlying asset of this cToken
   */
  function initialize(
    ILendPoolAddressesProvider addressProvider,
    address treasury,
    address underlyingAsset,
    uint8 cTokenDecimals,
    string calldata cTokenName,
    string calldata cTokenSymbol
  ) external;

  /**
   * @dev Emitted after the mint action
   * @param from The address performing the mint
   * @param value The amount being
   * @param index The new liquidity index of the reserve
   **/
  event Mint(address indexed from, uint256 value, uint256 index);

  /**
   * @dev Mints `amount` cTokens to `user`
   * @param user The address receiving the minted tokens
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   * @return `true` if the the previous balance of the user was 0
   */
  function mint(
    address user,
    uint256 amount,
    uint256 index
  ) external returns (bool);

  /**
   * @dev Emitted after cTokens are burned
   * @param from The owner of the cTokens, getting them burned
   * @param target The address that will receive the underlying
   * @param value The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  event Burn(address indexed from, address indexed target, uint256 value, uint256 index);

  /**
   * @dev Emitted during the transfer action
   * @param from The user whose tokens are being transferred
   * @param to The recipient
   * @param value The amount being transferred
   * @param index The new liquidity index of the reserve
   **/
  event BalanceTransfer(address indexed from, address indexed to, uint256 value, uint256 index);

  /**
   * @dev Burns cTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
   * @param user The owner of the cTokens, getting them burned
   * @param receiverOfUnderlying The address that will receive the underlying
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  function burn(
    address user,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external;

  /**
   * @dev Mints cTokens to the reserve treasury
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   */
  function mintToTreasury(uint256 amount, uint256 index) external;

  /**
   * @dev Transfers the underlying asset to `target`. Used by the LendPool to transfer
   * assets in borrow(), withdraw() and flashLoan()
   * @param user The recipient of the underlying
   * @param amount The amount getting transferred
   * @return The amount transferred
   **/
  function transferUnderlyingTo(address user, uint256 amount) external returns (uint256);

  /**
   * @dev Returns the address of the incentives controller contract
   **/
  function getIncentivesController() external view returns (IIncentivesController);

  /**
   * @dev Returns the address of the underlying asset of this cToken
   **/
  function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {ILendPoolAddressesProvider} from "../interfaces/ILendPoolAddressesProvider.sol";
import {IIncentivesController} from "./IIncentivesController.sol";
import {IScaledBalanceToken} from "./IScaledBalanceToken.sol";

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

/**
 * @title IDebtToken
 * @author Confetti
 * @notice Defines the basic interface for a debt token.
 **/
interface IDebtToken is IScaledBalanceToken, IERC20Upgradeable, IERC20MetadataUpgradeable {
  /**
   * @dev Emitted when a debt token is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param pool The address of the associated lend pool
   * @param incentivesController The address of the incentives controller
   * @param debtTokenDecimals the decimals of the debt token
   * @param debtTokenName the name of the debt token
   * @param debtTokenSymbol the symbol of the debt token
   **/
  event Initialized(
    address indexed underlyingAsset,
    address indexed pool,
    address incentivesController,
    uint8 debtTokenDecimals,
    string debtTokenName,
    string debtTokenSymbol
  );

  /**
   * @dev Initializes the debt token.
   * @param addressProvider The address of the lend pool
   * @param underlyingAsset The address of the underlying asset
   * @param debtTokenDecimals The decimals of the debtToken, same as the underlying asset's
   * @param debtTokenName The name of the token
   * @param debtTokenSymbol The symbol of the token
   */
  function initialize(
    ILendPoolAddressesProvider addressProvider,
    address underlyingAsset,
    uint8 debtTokenDecimals,
    string memory debtTokenName,
    string memory debtTokenSymbol
  ) external;

  /**
   * @dev Emitted after the mint action
   * @param from The address performing the mint
   * @param value The amount to be minted
   * @param index The last index of the reserve
   **/
  event Mint(address indexed from, uint256 value, uint256 index);

  /**
   * @dev Mints debt token to the `user` address
   * @param user The address receiving the borrowed underlying
   * @param amount The amount of debt being minted
   * @param index The variable debt index of the reserve
   * @return `true` if the the previous balance of the user is 0
   **/
  function mint(
    address user,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external returns (bool);

  /**
   * @dev Emitted when variable debt is burnt
   * @param user The user which debt has been burned
   * @param amount The amount of debt being burned
   * @param index The index of the user
   **/
  event Burn(address indexed user, uint256 amount, uint256 index);

  /**
   * @dev Burns user variable debt
   * @param user The user which debt is burnt
   * @param index The variable debt index of the reserve
   **/
  function burn(
    address user,
    uint256 amount,
    uint256 index
  ) external;

  /**
   * @dev Returns the address of the incentives controller contract
   **/
  function getIncentivesController() external view returns (IIncentivesController);

  /**
   * @dev delegates borrowing power to a user on the specific debt token
   * @param delegatee the address receiving the delegated borrowing power
   * @param amount the maximum amount being delegated. Delegation will still
   * respect the liquidation constraints (even if delegated, a delegatee cannot
   * force a delegator HF to go below 1)
   **/
  function approveDelegation(address delegatee, uint256 amount) external;

  /**
   * @dev returns the borrow allowance of the user
   * @param fromUser The user to giving allowance
   * @param toUser The user to give allowance to
   * @return the current allowance of toUser
   **/
  function borrowAllowance(address fromUser, address toUser) external view returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

/**
 * @title IInterestRate interface
 * @dev Interface for the calculation of the interest rates
 * @author Confetti
 */
interface IInterestRate {
  function baseVariableBorrowRate() external view returns (uint256);

  function getMaxVariableBorrowRate() external view returns (uint256);

  function calculateInterestRates(
    address reserve,
    uint256 availableLiquidity,
    uint256 totalVariableDebt,
    uint256 reserveFactor
  ) external view returns (uint256, uint256);

  function calculateInterestRates(
    address reserve,
    address cToken,
    uint256 liquidityAdded,
    uint256 liquidityTaken,
    uint256 totalVariableDebt,
    uint256 reserveFactor
  ) external view returns (uint256 liquidityRate, uint256 variableBorrowRate);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

import {WadRayMath} from "./WadRayMath.sol";

library MathUtils {
  using WadRayMath for uint256;

  /// @dev Ignoring leap years
  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  /**
   * @dev Function to calculate the interest accumulated using a linear interest rate formula
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate linearly accumulated during the timeDelta, in ray
   **/

  function calculateLinearInterest(uint256 rate, uint40 lastUpdateTimestamp) internal view returns (uint256) {
    //solium-disable-next-line
    uint256 timeDifference = block.timestamp - (uint256(lastUpdateTimestamp));

    return ((rate * (timeDifference)) / SECONDS_PER_YEAR) + (WadRayMath.ray());
  }

  /**
   * @dev Function to calculate the interest using a compounded interest rate formula
   * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
   *
   *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
   *
   * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great gas cost reductions
   * The whitepaper contains reference to the approximation and a table showing the margin of error per different time periods
   *
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate compounded during the timeDelta, in ray
   **/
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    //solium-disable-next-line
    uint256 exp = currentTimestamp - (uint256(lastUpdateTimestamp));

    if (exp == 0) {
      return WadRayMath.ray();
    }

    uint256 expMinusOne = exp - 1;

    uint256 expMinusTwo = exp > 2 ? exp - 2 : 0;

    uint256 ratePerSecond = rate / SECONDS_PER_YEAR;

    uint256 basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
    uint256 basePowerThree = basePowerTwo.rayMul(ratePerSecond);

    uint256 secondTerm = (exp * (expMinusOne) * (basePowerTwo)) / 2;
    uint256 thirdTerm = (exp * (expMinusOne) * (expMinusTwo) * (basePowerThree)) / 6;

    return WadRayMath.ray() + (ratePerSecond * (exp)) + (secondTerm) + (thirdTerm);
  }

  /**
   * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
   * @param rate The interest rate (in ray)
   * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
   **/
  function calculateCompoundedInterest(uint256 rate, uint40 lastUpdateTimestamp) internal view returns (uint256) {
    return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

interface IIncentivesController {
  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param asset The address of the user
   * @param totalSupply The total supply of the asset in the lending pool
   * @param userBalance The balance of the user of the asset in the lending pool
   **/
  function handleAction(
    address asset,
    uint256 totalSupply,
    uint256 userBalance
  ) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.4;

interface IScaledBalanceToken {
  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   **/
  function scaledBalanceOf(address user) external view returns (uint256);

  /**
   * @dev Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled balance and the scaled total supply
   **/
  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return The scaled total supply
   **/
  function scaledTotalSupply() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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