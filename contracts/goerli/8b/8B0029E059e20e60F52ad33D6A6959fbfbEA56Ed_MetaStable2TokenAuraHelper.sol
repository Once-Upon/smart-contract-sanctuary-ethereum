// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {
    MetaStable2TokenAuraStrategyContext,
    StableOracleContext,
    StrategyContext,
    TwoTokenPoolContext,
    RedeemParams,
    ReinvestRewardParams,
    StrategyVaultSettings,
    StrategyVaultState
} from "../BalancerVaultTypes.sol";
import {BalancerEvents} from "../BalancerEvents.sol";
import {SettlementUtils} from "../internal/settlement/SettlementUtils.sol";
import {StrategyUtils} from "../internal/strategy/StrategyUtils.sol";
import {TwoTokenPoolUtils} from "../internal/pool/TwoTokenPoolUtils.sol";
import {TwoTokenAuraRewardUtils} from "../internal/reward/TwoTokenAuraRewardUtils.sol";
import {Stable2TokenOracleMath} from "../internal/math/Stable2TokenOracleMath.sol";
import {BalancerVaultStorage} from "../internal/BalancerVaultStorage.sol";
import {IERC20} from "../../../../interfaces/IERC20.sol";

library MetaStable2TokenAuraHelper {
    using TwoTokenAuraRewardUtils for TwoTokenPoolContext;
    using TwoTokenPoolUtils for TwoTokenPoolContext;
    using Stable2TokenOracleMath for StableOracleContext;
    using StrategyUtils for StrategyContext;
    using SettlementUtils for StrategyContext;
    using BalancerVaultStorage for StrategyVaultSettings;

    function settleVault(
        MetaStable2TokenAuraStrategyContext calldata context,
        uint256 maturity,
        uint256 strategyTokensToRedeem,
        RedeemParams memory params
    ) external {
        uint256 bptToSettle = context.baseStrategy._convertStrategyTokensToBPTClaim(strategyTokensToRedeem);
        
        _executeSettlement({
            strategyContext: context.baseStrategy,
            oracleContext: context.oracleContext,
            poolContext: context.poolContext,
            maturity: maturity,
            bptToSettle: bptToSettle,
            redeemStrategyTokenAmount: strategyTokensToRedeem,
            params: params
        });

        emit BalancerEvents.VaultSettlement(maturity, bptToSettle, strategyTokensToRedeem);
    }

    function settleVaultEmergency(
        MetaStable2TokenAuraStrategyContext calldata context, 
        uint256 maturity, 
        bytes calldata data
    ) external {
        RedeemParams memory params = SettlementUtils._decodeParamsAndValidate(
            context.baseStrategy.vaultSettings.emergencySettlementSlippageLimitPercent,
            data
        );

        uint256 bptToSettle = context.baseStrategy._getEmergencySettlementParams({
            poolContext: context.poolContext.basePool, 
            maturity: maturity, 
            totalBPTSupply: IERC20(context.poolContext.basePool.pool).totalSupply()
        });

        uint256 redeemStrategyTokenAmount = 
            context.baseStrategy._convertBPTClaimToStrategyTokens(bptToSettle);

        _executeSettlement({
            strategyContext: context.baseStrategy,
            oracleContext: context.oracleContext,
            poolContext: context.poolContext,
            maturity: maturity,
            bptToSettle: bptToSettle,
            redeemStrategyTokenAmount: redeemStrategyTokenAmount,
            params: params
        });

        emit BalancerEvents.EmergencyVaultSettlement(maturity, bptToSettle, redeemStrategyTokenAmount);
    }

    function _executeSettlement(
        StrategyContext calldata strategyContext,
        StableOracleContext calldata oracleContext,
        TwoTokenPoolContext calldata poolContext,
        uint256 maturity,
        uint256 bptToSettle,
        uint256 redeemStrategyTokenAmount,
        RedeemParams memory params
    ) private {
        /// @notice params.minPrimary and params.minSecondary are not required for this strategy vault
        (params.minPrimary, params.minSecondary) = oracleContext._getMinExitAmounts({
            poolContext: poolContext,
            strategyContext: strategyContext,
            bptAmount: bptToSettle
        });

        int256 expectedUnderlyingRedeemed = poolContext._convertStrategyToUnderlying({
            strategyContext: strategyContext,
            oracleContext: oracleContext.baseOracle,
            strategyTokenAmount: redeemStrategyTokenAmount
        });

        strategyContext._executeSettlement({
            maturity: maturity,
            expectedUnderlyingRedeemed: expectedUnderlyingRedeemed,
            redeemStrategyTokenAmount: redeemStrategyTokenAmount,
            params: params
        });
    }

    function reinvestReward(
        MetaStable2TokenAuraStrategyContext calldata context,
        ReinvestRewardParams calldata params
    ) external {
        StrategyContext calldata strategyContext = context.baseStrategy;
        TwoTokenPoolContext calldata poolContext = context.poolContext; 
        StableOracleContext calldata oracleContext = context.oracleContext;

        (
            address rewardToken, 
            uint256 primaryAmount, 
            uint256 secondaryAmount
        ) = poolContext._executeRewardTrades(
            context.stakingContext,
            strategyContext.tradingModule,
            params.tradeData,
            strategyContext.vaultSettings.maxRewardTradeSlippageLimitPercent
        );

        // Make sure we are joining with the right proportion to minimize slippage
        oracleContext._validateSpotPriceAndPairPrice({
            poolContext: poolContext,
            strategyContext: strategyContext,
            primaryAmount: primaryAmount,
            secondaryAmount: secondaryAmount
        });

        uint256 bptAmount = poolContext._joinPoolAndStake({
            strategyContext: strategyContext,
            stakingContext: context.stakingContext,
            primaryAmount: primaryAmount,
            secondaryAmount: secondaryAmount,
            /// @notice minBPT is not required to be set by the caller because primaryAmount
            /// and secondaryAmount are already validated
            minBPT: params.minBPT        
        });

        emit BalancerEvents.RewardReinvested(rewardToken, primaryAmount, secondaryAmount, bptAmount); 
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function decimals() external view returns (uint8);

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IStrategyVault} from "../../../interfaces/notional/IStrategyVault.sol";
import {VaultConfig} from "../../../interfaces/notional/IVaultController.sol";
import {IAuraBooster} from "../../../interfaces/aura/IAuraBooster.sol";
import {IAuraRewardPool} from "../../../interfaces/aura/IAuraRewardPool.sol";
import {NotionalProxy} from "../../../interfaces/notional/NotionalProxy.sol";
import {ILiquidityGauge} from "../../../interfaces/balancer/ILiquidityGauge.sol";
import {IBalancerVault} from "../../../interfaces/balancer/IBalancerVault.sol";
import {IBalancerMinter} from "../../../interfaces/balancer/IBalancerMinter.sol";
import {IPriceOracle} from "../../../interfaces/balancer/IPriceOracle.sol";
import {IAsset} from "../../../interfaces/balancer/IBalancerVault.sol";
import {ITradingModule, Trade, TradeType} from "../../../interfaces/trading/ITradingModule.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";

struct DeploymentParams {
    uint16 primaryBorrowCurrencyId;
    bytes32 balancerPoolId;
    ILiquidityGauge liquidityGauge;
    ITradingModule tradingModule;
    uint32 settlementPeriodInSeconds;
    address feeReceiver;
}

struct AuraVaultDeploymentParams {
    IAuraRewardPool auraRewardPool;
    DeploymentParams baseParams;
}

struct InitParams {
    string name;
    uint16 borrowCurrencyId;
    StrategyVaultSettings settings;
}

struct DepositParams {
    uint256 minBPT;
    bytes tradeData;
}

struct DepositTradeParams {
    uint256 tradeAmount;
    DynamicTradeParams tradeParams;
}

struct RedeemParams {
    uint256 minPrimary;
    uint256 minSecondary;
    bytes secondaryTradeParams;
}

/// @notice Parameters for dynamic slippage trades
struct DynamicTradeParams {
    uint16 dexId;
    TradeType tradeType;
    uint32 oracleSlippagePercent;
    bool tradeUnwrapped;
    bytes exchangeData;
}

/// @notice Parameters for joining/exiting Balancer pools
struct PoolParams {
    IAsset[] assets;
    uint256[] amounts;
    uint256 msgValue;
}

struct OracleContext {
    uint256 oracleWindowInSeconds;
    uint256 balancerOracleWeight;
}

struct StableOracleContext {
    /// @notice Amplification parameter
    uint256 ampParam;
    OracleContext baseOracle;
}

struct UnderlyingPoolContext {
    uint256 scaleFactor;
    uint256 mainBalance;
    uint256 wrappedBalance;
    uint256 virtualSupply;
    uint256 fee;
    uint256 lowerTarget;
    uint256 upperTarget;
}

struct BoostedOracleContext {
    /// @notice Amplification parameter
    uint256 ampParam;
    /// @notice BPT balance in the pool
    uint256 bptBalance;
    /// @notice Protocol fee amount used to calculate the virtual supply
    uint256 dueProtocolFeeBptAmount;
    /// @notice Primary scale factor used for downscaling
    uint256 primaryScaleFactor;
    /// @notice Underlying linear pool for the primary token
    UnderlyingPoolContext primaryUnderlyingPool;
}

/// @notice Balancer pool related fields
struct PoolContext {
    IERC20 pool;
    bytes32 poolId;
}

struct AuraStakingContext {
    ILiquidityGauge liquidityGauge;
    IAuraBooster auraBooster;
    IAuraRewardPool auraRewardPool;
    uint256 auraPoolId;
    IERC20[] rewardTokens;
}

struct TwoTokenPoolContext {
    address primaryToken;
    address secondaryToken;
    uint8 primaryIndex;
    uint8 secondaryIndex;
    uint8 primaryDecimals;
    uint8 secondaryDecimals;
    uint256 primaryBalance;
    uint256 secondaryBalance;
    PoolContext basePool;
}

struct ThreeTokenPoolContext {
    address tertiaryToken;
    uint8 tertiaryIndex;
    uint8 tertiaryDecimals;
    uint256 tertiaryBalance;
    TwoTokenPoolContext basePool;
}

struct StrategyContext {
    uint256 totalBPTHeld;
    uint32 settlementPeriodInSeconds;
    ITradingModule tradingModule;
    StrategyVaultSettings vaultSettings;
    StrategyVaultState vaultState;
    address feeReceiver;
}

struct MetaStable2TokenAuraStrategyContext {
    TwoTokenPoolContext poolContext;
    StableOracleContext oracleContext;
    AuraStakingContext stakingContext;
    StrategyContext baseStrategy;
}

struct Boosted3TokenAuraStrategyContext {
    ThreeTokenPoolContext poolContext;
    BoostedOracleContext oracleContext;
    AuraStakingContext stakingContext;
    StrategyContext baseStrategy;
}

struct NormalSettlementData {
    uint256 maxUnderlyingSurplus;
    uint256 redeemStrategyTokenAmount;
    int256 underlyingCashRequiredToSettle;
}

struct BoostedSettlementData {
    uint256 maxUnderlyingSurplus;
    uint256 primarySettlementBalance;
    uint256 redeemStrategyTokenAmount;
    int256 underlyingCashRequiredToSettle;
}

struct Balanced2TokenRewardTradeParams {
    SingleSidedRewardTradeParams primaryTrade;
    SingleSidedRewardTradeParams secondaryTrade;
}

struct SingleSidedRewardTradeParams {
    address sellToken;
    address buyToken;
    uint256 amount;
    DynamicTradeParams tradeParams;
}

struct ReinvestRewardParams {
    bytes tradeData;
    uint256 minBPT;
}

struct StrategyVaultSettings {
    uint256 maxUnderlyingSurplus;
    /// @notice Balancer oracle window in seconds
    uint32 oracleWindowInSeconds;
    /// @notice Slippage limit for normal settlement
    uint32 settlementSlippageLimitPercent;
    /// @notice Slippage limit for post maturity settlement
    uint32 postMaturitySettlementSlippageLimitPercent;
    /// @notice Slippage limit for emergency settlement (vault owns too much of the Balancer pool)
    uint32 emergencySettlementSlippageLimitPercent;
    /// @notice Slippage limit for selling reward tokens
    uint32 maxRewardTradeSlippageLimitPercent;
    uint16 maxBalancerPoolShare;
    uint16 balancerOracleWeight;
    /// @notice Cool down in minutes for normal settlement
    uint16 settlementCoolDownInMinutes;
    /// @notice Determines the amount of BAL transferred to FEE_RECEIVER
    uint16 feePercentage;
    /// @notice Limits the amount of allowable deviation from the oracle price
    uint16 oraclePriceDeviationLimitPercent;
    /// @notice Slippage limit for joining/exiting Balancer pools
    uint16 balancerPoolSlippageLimitPercent;
}

struct StrategyVaultState {
    /// @notice Total number of strategy tokens across all maturities
    uint80 totalStrategyTokenGlobal;
    uint32 lastSettlementTimestamp;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

import {StrategyVaultSettings} from "./BalancerVaultTypes.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";

library BalancerEvents {
    event RewardReinvested(address token, uint256 primaryAmount, uint256 secondaryAmount, uint256 bptAmount);
    event VaultSettlement(
        uint256 maturity,
        uint256 bptToSettle,
        uint256 strategyTokensRedeemed
    );

    event EmergencyVaultSettlement(
        uint256 maturity,
        uint256 bptToSettle,
        uint256 redeemStrategyTokenAmount
    );

    event StrategyVaultSettingsUpdated(StrategyVaultSettings settings);

    event ClaimedRewardTokens(IERC20[] rewardTokens, uint256[] claimedBalances);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {StrategyVaultSettings, StrategyVaultState} from "../BalancerVaultTypes.sol";
import {BalancerEvents} from "../BalancerEvents.sol";
import {BalancerConstants} from "./BalancerConstants.sol";

library BalancerVaultStorage {
    uint256 private constant STRATEGY_VAULT_SETTINGS_SLOT = 1000001;
    uint256 private constant STRATEGY_VAULT_STATE_SLOT    = 1000002;

    function _settings() private pure returns (mapping(uint256 => StrategyVaultSettings) storage store) {
        assembly { store.slot := STRATEGY_VAULT_SETTINGS_SLOT }
    }

    function _state() private pure returns (mapping(uint256 => StrategyVaultState) storage store) {
        assembly { store.slot := STRATEGY_VAULT_STATE_SLOT }
    }

    function getStrategyVaultSettings() internal view returns (StrategyVaultSettings memory) {
        // Hardcode to the zero slot
        return _settings()[0];
    }

    function setStrategyVaultSettings(
        StrategyVaultSettings memory settings, 
        uint32 maxOracleQueryWindow,
        uint16 balancerOracleWeight
    ) internal {
        require(settings.oracleWindowInSeconds <= maxOracleQueryWindow);
        require(settings.settlementCoolDownInMinutes <= BalancerConstants.MAX_SETTLEMENT_COOLDOWN_IN_MINUTES);
        require(settings.maxRewardTradeSlippageLimitPercent <= BalancerConstants.SLIPPAGE_LIMIT_PRECISION);
        require(settings.balancerOracleWeight <= balancerOracleWeight);
        require(settings.maxBalancerPoolShare <= BalancerConstants.VAULT_PERCENT_BASIS);
        require(settings.settlementSlippageLimitPercent <= BalancerConstants.SLIPPAGE_LIMIT_PRECISION);
        require(settings.postMaturitySettlementSlippageLimitPercent <= BalancerConstants.SLIPPAGE_LIMIT_PRECISION);
        require(settings.emergencySettlementSlippageLimitPercent <= BalancerConstants.SLIPPAGE_LIMIT_PRECISION);
        require(settings.feePercentage <= BalancerConstants.VAULT_PERCENT_BASIS);
        require(settings.oraclePriceDeviationLimitPercent <= BalancerConstants.VAULT_PERCENT_BASIS);

        mapping(uint256 => StrategyVaultSettings) storage store = _settings();
        // Hardcode to the zero slot
        store[0] = settings;

        emit BalancerEvents.StrategyVaultSettingsUpdated(settings);
    }

    function getStrategyVaultState() internal view returns (StrategyVaultState memory) {
        // Hardcode to the zero slot
        return _state()[0];
    }

    function setStrategyVaultState(StrategyVaultState memory state) internal {
        mapping(uint256 => StrategyVaultState) storage store = _state();
        // Hardcode to the zero slot
        store[0] = state;
    }

    function _bptThreshold(StrategyVaultSettings memory strategyVaultSettings, uint256 totalBPTSupply) 
        internal pure returns (uint256) {
        return (totalBPTSupply * strategyVaultSettings.maxBalancerPoolShare) / BalancerConstants.VAULT_PERCENT_BASIS;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {StableOracleContext, TwoTokenPoolContext, StrategyContext} from "../../BalancerVaultTypes.sol";
import {BalancerConstants} from "../BalancerConstants.sol";
import {Errors} from "../../../../global/Errors.sol";
import {TypeConvert} from "../../../../global/TypeConvert.sol";
import {IPriceOracle} from "../../../../../interfaces/balancer/IPriceOracle.sol";
import {StableMath} from "./StableMath.sol";
import {ITradingModule} from "../../../../../interfaces/trading/ITradingModule.sol";

library Stable2TokenOracleMath {
    using TypeConvert for int256;
    using Stable2TokenOracleMath for StableOracleContext;

    function _getSpotPrice(
        StableOracleContext memory oracleContext, 
        TwoTokenPoolContext memory poolContext, 
        uint256 tokenIndex
    ) internal view returns (uint256 spotPrice) {
        // Prevents overflows, we don't expect tokens to be greater than 18 decimals, don't use
        // equal sign for minor gas optimization
        require(poolContext.primaryDecimals < 19); /// @dev primaryDecimals overflow
        require(poolContext.secondaryDecimals < 19); /// @dev secondaryDecimals overflow
        require(tokenIndex < 2); /// @dev invalid token index

        (uint256 balanceX, uint256 balanceY) = tokenIndex == 0 ?
            (poolContext.primaryBalance, poolContext.secondaryBalance) :
            (poolContext.secondaryBalance, poolContext.primaryBalance);

        uint256 invariant = StableMath._calculateInvariant(
            oracleContext.ampParam, StableMath._balances(balanceX, balanceY), true // round up
        );

        spotPrice = StableMath._calcSpotPrice({
            amplificationParameter: oracleContext.ampParam,
            invariant: invariant,
            balanceX: balanceX,
            balanceY: balanceY
        });
    }

    function _checkPriceLimit(
        StrategyContext calldata strategyContext,
        TwoTokenPoolContext memory poolContext,
        uint256 poolPrice
    ) private view returns (bool) {
        (
            int256 answer, int256 decimals
        ) = strategyContext.tradingModule.getOraclePrice(poolContext.secondaryToken, poolContext.primaryToken);

        require(decimals == int256(BalancerConstants.BALANCER_PRECISION));

        uint256 oraclePairPrice = answer.toUint();
        uint256 lowerLimit = (oraclePairPrice * 
            (BalancerConstants.VAULT_PERCENT_BASIS - strategyContext.vaultSettings.oraclePriceDeviationLimitPercent)) / 
            BalancerConstants.VAULT_PERCENT_BASIS;
        uint256 upperLimit = (oraclePairPrice * 
            (BalancerConstants.VAULT_PERCENT_BASIS + strategyContext.vaultSettings.oraclePriceDeviationLimitPercent)) / 
            BalancerConstants.VAULT_PERCENT_BASIS;

        if (poolPrice < lowerLimit || upperLimit < poolPrice) {
            revert Errors.InvalidPrice(oraclePairPrice, poolPrice);
        }
    }

    /// @notice calculates the expected min exit amounts for a given BPT amount
    function _getMinExitAmounts(
        StableOracleContext calldata oracleContext,
        TwoTokenPoolContext calldata poolContext,
        StrategyContext calldata strategyContext,
        uint256 bptAmount
    ) internal view returns (uint256 minPrimary, uint256 minSecondary) {
        // Oracle price is always specified in terms of primary, so tokenIndex == 0 for primary
        // Validate the spot price to make sure the pool is not being manipulated
        uint256 spotPrice = _getSpotPrice(oracleContext, poolContext, 0);
        _checkPriceLimit(strategyContext, poolContext, spotPrice);

        // min amounts are calculated based on the share of the Balancer pool with a small discount applied
        uint256 totalBPTSupply = poolContext.basePool.pool.totalSupply();
        minPrimary = (poolContext.primaryBalance * bptAmount * 
            strategyContext.vaultSettings.balancerPoolSlippageLimitPercent) / 
            (totalBPTSupply * uint256(BalancerConstants.VAULT_PERCENT_BASIS));
        minSecondary = (poolContext.secondaryBalance * bptAmount * 
            strategyContext.vaultSettings.balancerPoolSlippageLimitPercent) / 
            (totalBPTSupply * uint256(BalancerConstants.VAULT_PERCENT_BASIS));
    }

    function _validateSpotPriceAndPairPrice(
        StableOracleContext calldata oracleContext,
        TwoTokenPoolContext calldata poolContext,
        StrategyContext calldata strategyContext,
        uint256 primaryAmount, 
        uint256 secondaryAmount
    ) internal view {
        // Oracle price is always specified in terms of primary, so tokenIndex == 0 for primary
        uint256 spotPrice = _getSpotPrice(oracleContext, poolContext, 0);
        _checkPriceLimit(strategyContext, poolContext, spotPrice);

        // We always validate in terms of the primary here so it is the first value in the _balances array
        uint256 invariant = StableMath._calculateInvariant(
            oracleContext.ampParam, StableMath._balances(primaryAmount, secondaryAmount), true // round up
        );

        /// @notice Balancer math functions expect all amounts to be in BALANCER_PRECISION
        uint256 primaryPrecision = 10 ** poolContext.primaryDecimals;
        uint256 secondaryPrecision = 10 ** poolContext.secondaryDecimals;
        primaryAmount = primaryAmount * BalancerConstants.BALANCER_PRECISION / primaryPrecision;
        secondaryAmount = secondaryAmount * BalancerConstants.BALANCER_PRECISION / secondaryPrecision;

        uint256 calculatedPairPrice = StableMath._calcSpotPrice({
            amplificationParameter: oracleContext.ampParam,
            invariant: invariant,
            balanceX: primaryAmount,
            balanceY: secondaryAmount
        });

        _checkPriceLimit(strategyContext, poolContext, calculatedPairPrice);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {
    RedeemParams, 
    DynamicTradeParams,
    StrategyContext,
    PoolContext,
    StrategyVaultSettings,
    StrategyVaultState
} from "../../BalancerVaultTypes.sol";
import {VaultState} from "../../../../global/Types.sol";
import {Errors} from "../../../../global/Errors.sol";
import {Deployments} from "../../../../global/Deployments.sol";
import {Constants} from "../../../../global/Constants.sol";
import {BalancerConstants} from "../BalancerConstants.sol";
import {TypeConvert} from "../../../../global/TypeConvert.sol";
import {StrategyUtils} from "../strategy/StrategyUtils.sol";
import {BalancerVaultStorage} from "../BalancerVaultStorage.sol";

library SettlementUtils {
    using TypeConvert for uint256;
    using TypeConvert for int256;
    using StrategyUtils for StrategyContext;
    using BalancerVaultStorage for StrategyVaultSettings;

    /// @notice Validates that the slippage passed in by the caller
    /// does not exceed the designated threshold.
    /// @param slippageLimitPercent configured limit on the slippage from the oracle price allowed
    /// @param data trade parameters passed into settlement
    /// @return params abi decoded redemption parameters
    function _decodeParamsAndValidate(
        uint32 slippageLimitPercent,
        bytes memory data
    ) internal view returns (RedeemParams memory params) {
        params = abi.decode(data, (RedeemParams));
        DynamicTradeParams memory callbackData = abi.decode(
            params.secondaryTradeParams, (DynamicTradeParams)
        );

        if (callbackData.oracleSlippagePercent > slippageLimitPercent) {
            revert Errors.SlippageTooHigh(callbackData.oracleSlippagePercent, slippageLimitPercent);
        }
    }

    /// @notice Validates that the settlement is past a specified cool down period.
    /// @param lastSettlementTimestamp the last time the vault was settled
    /// @param coolDownInMinutes configured length of time required between settlements to ensure that
    /// slippage thresholds are respected (gives the market time to arbitrage back into position)
    function _validateCoolDown(uint32 lastSettlementTimestamp, uint32 coolDownInMinutes) internal view {
        // Convert coolDown to seconds
        if (lastSettlementTimestamp + (coolDownInMinutes * 60) > block.timestamp)
            revert Errors.InSettlementCoolDown(lastSettlementTimestamp, coolDownInMinutes);
    }

    /// @notice Calculates the amount of BPT availTable for emergency settlement
    function _getEmergencySettlementBPTAmount(
        uint256 bptTotalSupply,
        uint16 maxBalancerPoolShare,
        uint256 totalBPTHeld,
        uint256 bptHeldInMaturity
    ) private pure returns (uint256 bptToSettle) {
        // desiredPoolShare = maxPoolShare * bufferPercentage
        uint256 desiredPoolShare = (maxBalancerPoolShare *
            BalancerConstants.BALANCER_POOL_SHARE_BUFFER) /
            BalancerConstants.VAULT_PERCENT_BASIS;
        uint256 desiredBPTAmount = (bptTotalSupply * desiredPoolShare) /
            BalancerConstants.VAULT_PERCENT_BASIS;
        
        bptToSettle = totalBPTHeld - desiredBPTAmount;

        // Check to make sure we are not settling more than the amount of BPT
        // available in the current maturity
        // If more settlement is needed, call settleVaultEmergency
        // again with a different maturity
        if (bptToSettle > bptHeldInMaturity) {
            bptToSettle = bptHeldInMaturity;
        }
    }

    function _totalSupplyInMaturity(uint256 maturity) private view returns (uint256) {
        VaultState memory vaultState = Deployments.NOTIONAL.getVaultState(address(this), maturity);
        return vaultState.totalStrategyTokens;
    }

    function _getEmergencySettlementParams(
        StrategyContext memory strategyContext,
        PoolContext memory poolContext,
        uint256 maturity,
        uint256 totalBPTSupply
    )  internal view returns(uint256 bptToSettle) {
        StrategyVaultSettings memory settings = strategyContext.vaultSettings;
        StrategyVaultState memory state = strategyContext.vaultState;

        // Not in settlement window, check if BPT held is greater than maxBalancerPoolShare * total BPT supply
        uint256 emergencyBPTWithdrawThreshold = settings._bptThreshold(totalBPTSupply);

        if (strategyContext.totalBPTHeld <= emergencyBPTWithdrawThreshold)
            revert Errors.InvalidEmergencySettlement();

        uint256 bptHeldInMaturity = _getBPTHeldInMaturity(
            state,
            _totalSupplyInMaturity(maturity),
            strategyContext.totalBPTHeld
        );

        bptToSettle = _getEmergencySettlementBPTAmount({
            bptTotalSupply: totalBPTSupply,
            maxBalancerPoolShare: settings.maxBalancerPoolShare,
            totalBPTHeld: strategyContext.totalBPTHeld,
            bptHeldInMaturity: bptHeldInMaturity
        });
    }

    function _executeSettlement(
        StrategyContext memory context,
        uint256 maturity,
        int256 expectedUnderlyingRedeemed,
        uint256 redeemStrategyTokenAmount,
        RedeemParams memory params
    ) internal {
        ( /* int256 assetCashRequiredToSettle */, int256 underlyingCashRequiredToSettle) 
            = Deployments.NOTIONAL.getCashRequiredToSettle(address(this), maturity);

        // A negative surplus here means the account is insolvent
        // (either expectedUnderlyingRedeemed is negative or
        // expectedUnderlyingRedeemed is less than underlyingCashRequiredToSettle).
        // If that's the case, we should just redeem and repay as much as possible (surplus
        // check is ignored because maxUnderlyingSurplus can never be negative).
        // If underlyingCashRequiredToSettle is negative, that means we already have surplus cash
        // on the Notional side, it will just make the surplus larger and potentially
        // cause it to go over maxUnderlyingSurplus.
        int256 surplus = expectedUnderlyingRedeemed -
            underlyingCashRequiredToSettle;

        // Make sure we not redeeming too much to underlying
        // This allows BPT to be accrued as the profit token.
        if (surplus > context.vaultSettings.maxUnderlyingSurplus.toInt()) {
            revert Errors.RedeemingTooMuch(
                expectedUnderlyingRedeemed,
                underlyingCashRequiredToSettle
            );
        }

        ( /* int256 assetCashSurplus */, int256 underlyingCashSurplus) 
            = Deployments.NOTIONAL.redeemStrategyTokensToCash(
                maturity, redeemStrategyTokenAmount, abi.encode(params)
            );

        if (underlyingCashSurplus <= 0 && maturity <= block.timestamp) {
            Deployments.NOTIONAL.settleVault(address(this), maturity);
        }
    }

    function _getBPTHeldInMaturity(
        StrategyVaultState memory strategyVaultState, 
        uint256 totalSupplyInMaturity,
        uint256 totalBPTHeld
    ) private pure returns (uint256 bptHeldInMaturity) {
        if (strategyVaultState.totalStrategyTokenGlobal == 0) return 0;
        bptHeldInMaturity =
            (totalBPTHeld * totalSupplyInMaturity) /
            strategyVaultState.totalStrategyTokenGlobal;
    }

}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {
    Balanced2TokenRewardTradeParams,
    SingleSidedRewardTradeParams,
    ReinvestRewardParams,
    StrategyContext,
    PoolContext,
    AuraStakingContext,
    TwoTokenPoolContext
} from "../../BalancerVaultTypes.sol";
import {Errors} from "../../../../global/Errors.sol";
import {BalancerEvents} from "../../BalancerEvents.sol";
import {BalancerConstants} from "../BalancerConstants.sol";
import {BalancerUtils} from "../pool/BalancerUtils.sol";
import {ITradingModule} from "../../../../../interfaces/trading/ITradingModule.sol";
import {TwoTokenPoolUtils} from "../pool/TwoTokenPoolUtils.sol";
import {StrategyUtils} from "../strategy/StrategyUtils.sol";
import {AuraStakingUtils} from "../staking/AuraStakingUtils.sol";

library TwoTokenAuraRewardUtils {
    using TwoTokenPoolUtils for TwoTokenPoolContext;
    using AuraStakingUtils for AuraStakingContext;

    function _validateTrades(
        AuraStakingContext calldata context,
        SingleSidedRewardTradeParams memory primaryTrade,
        SingleSidedRewardTradeParams memory secondaryTrade,
        address primaryToken,
        address secondaryToken
    ) private pure {
        // Validate trades
        if (!context._isValidRewardToken(primaryTrade.sellToken)) {
            revert Errors.InvalidRewardToken(primaryTrade.sellToken);
        }
        if (secondaryTrade.sellToken != primaryTrade.sellToken) {
            revert Errors.InvalidRewardToken(secondaryTrade.sellToken);
        }
        if (primaryTrade.buyToken != primaryToken) {
            revert Errors.InvalidRewardToken(primaryTrade.buyToken);
        }
        if (secondaryTrade.buyToken != secondaryToken) {
            revert Errors.InvalidRewardToken(secondaryTrade.buyToken);
        }
    }

    function _executeRewardTrades(
        TwoTokenPoolContext calldata poolContext,
        AuraStakingContext calldata stakingContext,
        ITradingModule tradingModule,
        bytes calldata data,
        uint256 slippageLimit
    ) internal returns (address rewardToken, uint256 primaryAmount, uint256 secondaryAmount) {
        Balanced2TokenRewardTradeParams memory params = abi.decode(
            data,
            (Balanced2TokenRewardTradeParams)
        );

        require(params.primaryTrade.tradeParams.oracleSlippagePercent <= slippageLimit);
        require(params.secondaryTrade.tradeParams.oracleSlippagePercent <= slippageLimit);

        _validateTrades(
            stakingContext,
            params.primaryTrade,
            params.secondaryTrade,
            poolContext.primaryToken,
            poolContext.secondaryToken
        );

        (/*uint256 amountSold*/, primaryAmount) = StrategyUtils._executeDynamicTradeExactIn({
            params: params.primaryTrade.tradeParams,
            tradingModule: tradingModule,
            sellToken: params.primaryTrade.sellToken,
            buyToken: params.primaryTrade.buyToken,
            amount: params.primaryTrade.amount
        });

        (/*uint256 amountSold*/, secondaryAmount) = StrategyUtils._executeDynamicTradeExactIn({
            params: params.secondaryTrade.tradeParams,
            tradingModule: tradingModule,
            sellToken: params.secondaryTrade.sellToken,
            buyToken: params.secondaryTrade.buyToken,
            amount: params.secondaryTrade.amount
        });

        rewardToken = params.primaryTrade.sellToken;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import { StrategyContext, DynamicTradeParams } from "../../BalancerVaultTypes.sol";
import {TokenUtils, IERC20} from "../../../../utils/TokenUtils.sol";
import {TradeHandler} from "../../../../trading/TradeHandler.sol";
import {BalancerUtils} from "../pool/BalancerUtils.sol";
import {Deployments} from "../../../../global/Deployments.sol";
import {Constants} from "../../../../global/Constants.sol";
import {BalancerConstants} from "../BalancerConstants.sol";
import {ITradingModule, Trade, TradeType} from "../../../../../interfaces/trading/ITradingModule.sol";

library StrategyUtils {
    using TradeHandler for Trade;
    using TokenUtils for IERC20;

    /// @notice Converts strategy tokens to BPT
    function _convertStrategyTokensToBPTClaim(StrategyContext memory context, uint256 strategyTokenAmount)
        internal pure returns (uint256 bptClaim) {
        require(strategyTokenAmount <= context.vaultState.totalStrategyTokenGlobal);
        if (context.vaultState.totalStrategyTokenGlobal > 0) {
            bptClaim = (strategyTokenAmount * context.totalBPTHeld) / context.vaultState.totalStrategyTokenGlobal;
        }
    }

    /// @notice Converts BPT to strategy tokens
    function _convertBPTClaimToStrategyTokens(StrategyContext memory context, uint256 bptClaim)
        internal pure returns (uint256 strategyTokenAmount) {
        if (context.totalBPTHeld == 0) {
            // Strategy tokens are in 8 decimal precision, BPT is in 18. Scale the minted amount down.
            return (bptClaim * uint256(Constants.INTERNAL_TOKEN_PRECISION)) / 
                BalancerConstants.BALANCER_PRECISION;
        }

        // BPT held in maturity is calculated before the new BPT tokens are minted, so this calculation
        // is the tokens minted that will give the account a corresponding share of the new bpt balance held.
        // The precision here will be the same as strategy token supply.
        strategyTokenAmount = (bptClaim * context.vaultState.totalStrategyTokenGlobal) / context.totalBPTHeld;
    }

    function _executeDynamicTradeExactIn(
        DynamicTradeParams memory params,
        ITradingModule tradingModule,
        address sellToken,
        address buyToken,
        uint256 amount
    ) internal returns (uint256 amountSold, uint256 amountBought) {
        require(
            params.tradeType == TradeType.EXACT_IN_SINGLE || params.tradeType == TradeType.EXACT_IN_BATCH
        );

        // stETH generally has deeper liquidity than wstETH, setting tradeUnwrapped
        // to lets the contract trade in stETH instead of wstETH
        if (params.tradeUnwrapped && sellToken == address(Deployments.WRAPPED_STETH)) {
            sellToken = Deployments.WRAPPED_STETH.stETH();
            uint256 unwrappedAmount = IERC20(sellToken).balanceOf(address(this));
            // NOTE: the amount returned by unwrap is not always accurate for some reason
            Deployments.WRAPPED_STETH.unwrap(amount);
            amount = IERC20(sellToken).balanceOf(address(this)) - unwrappedAmount;
        }
        if (params.tradeUnwrapped && buyToken == address(Deployments.WRAPPED_STETH)) {
            buyToken = Deployments.WRAPPED_STETH.stETH();
        }

        // Sell residual secondary balance
        Trade memory trade = Trade(
            params.tradeType,
            sellToken,
            buyToken,
            amount,
            0,
            block.timestamp, // deadline
            params.exchangeData
        );

        (amountSold, amountBought) = trade._executeTradeWithDynamicSlippage(
            params.dexId, tradingModule, params.oracleSlippagePercent
        );

        if (
            params.tradeUnwrapped && 
            buyToken == address(Deployments.WRAPPED_STETH) && 
            amountBought > 0
        ) {
            IERC20(buyToken).checkApprove(address(Deployments.WRAPPED_STETH), amountBought);
            uint256 wrappedAmount = Deployments.WRAPPED_STETH.balanceOf(address(this));
            /// @notice the amount returned by wrap is not always accurate for some reason
            Deployments.WRAPPED_STETH.wrap(amountBought);
            amountBought = Deployments.WRAPPED_STETH.balanceOf(address(this)) - wrappedAmount;
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {
    TwoTokenPoolContext, 
    OracleContext, 
    PoolParams,
    DepositParams,
    DynamicTradeParams,
    DepositTradeParams,
    RedeemParams,
    AuraStakingContext,
    StrategyContext,
    StrategyVaultSettings,
    StrategyVaultState
} from "../../BalancerVaultTypes.sol";
import {Deployments} from "../../../../global/Deployments.sol";
import {BalancerConstants} from "../BalancerConstants.sol";
import {Errors} from "../../../../global/Errors.sol";
import {Constants} from "../../../../global/Constants.sol";
import {TypeConvert} from "../../../../global/TypeConvert.sol";
import {IAsset} from "../../../../../interfaces/balancer/IBalancerVault.sol";
import {TradeHandler} from "../../../../trading/TradeHandler.sol";
import {BalancerUtils} from "../pool/BalancerUtils.sol";
import {AuraStakingUtils} from "../staking/AuraStakingUtils.sol";
import {BalancerVaultStorage} from "../BalancerVaultStorage.sol";
import {StrategyUtils} from "../strategy/StrategyUtils.sol";
import {TwoTokenPoolUtils} from "../pool/TwoTokenPoolUtils.sol";
import {ITradingModule, Trade} from "../../../../../interfaces/trading/ITradingModule.sol";
import {IPriceOracle} from "../../../../../interfaces/balancer/IPriceOracle.sol";
import {TokenUtils, IERC20} from "../../../../utils/TokenUtils.sol";

library TwoTokenPoolUtils {
    using TokenUtils for IERC20;
    using TwoTokenPoolUtils for TwoTokenPoolContext;
    using TradeHandler for Trade;
    using TypeConvert for uint256;
    using StrategyUtils for StrategyContext;
    using AuraStakingUtils for AuraStakingContext;
    using BalancerVaultStorage for StrategyVaultSettings;
    using BalancerVaultStorage for StrategyVaultState;

    /// @notice Returns parameters for joining and exiting Balancer pools
    function _getPoolParams(
        TwoTokenPoolContext memory context,
        uint256 primaryAmount,
        uint256 secondaryAmount,
        bool isJoin
    ) internal pure returns (PoolParams memory) {
        IAsset[] memory assets = new IAsset[](2);
        assets[context.primaryIndex] = IAsset(context.primaryToken);
        assets[context.secondaryIndex] = IAsset(context.secondaryToken);

        uint256[] memory amounts = new uint256[](2);
        amounts[context.primaryIndex] = primaryAmount;
        amounts[context.secondaryIndex] = secondaryAmount;

        uint256 msgValue;
        if (isJoin && assets[context.primaryIndex] == IAsset(Deployments.ETH_ADDRESS)) {
            msgValue = amounts[context.primaryIndex];
        }

        return PoolParams(assets, amounts, msgValue);
    }

    /// @notice Gets the oracle price pair price between two tokens using a weighted
    /// average between a chainlink oracle and the balancer TWAP oracle.
    /// @param poolContext oracle context variables
    /// @param oracleContext oracle context variables
    /// @param tradingModule address of the trading module
    /// @return oraclePairPrice oracle price for the pair in 18 decimals
    function _getOraclePairPrice(
        TwoTokenPoolContext memory poolContext,
        OracleContext memory oracleContext, 
        ITradingModule tradingModule
    ) internal view returns (uint256 oraclePairPrice) {
        // NOTE: this balancer price is denominated in 18 decimal places
        uint256 balancerWeightedPrice;
        if (oracleContext.balancerOracleWeight > 0) {
            uint256 balancerPrice = BalancerUtils._getTimeWeightedOraclePrice(
                address(poolContext.basePool.pool),
                IPriceOracle.Variable.PAIR_PRICE,
                oracleContext.oracleWindowInSeconds
            );

            if (poolContext.primaryIndex == 1) {
                // If the primary index is the second token, we need to invert
                // the balancer price.
                balancerPrice = BalancerConstants.BALANCER_PRECISION_SQUARED / balancerPrice;
            }

            balancerWeightedPrice = balancerPrice * oracleContext.balancerOracleWeight;
        }

        uint256 chainlinkWeightedPrice;
        if (oracleContext.balancerOracleWeight < BalancerConstants.BALANCER_ORACLE_WEIGHT_PRECISION) {
            (int256 rate, int256 decimals) = tradingModule.getOraclePrice(
                poolContext.primaryToken, poolContext.secondaryToken
            );
            require(rate > 0);
            require(decimals >= 0);

            if (uint256(decimals) != BalancerConstants.BALANCER_PRECISION) {
                rate = (rate * int256(BalancerConstants.BALANCER_PRECISION)) / decimals;
            }

            // No overflow in rate conversion, checked above
            chainlinkWeightedPrice = uint256(rate) * 
                (BalancerConstants.BALANCER_ORACLE_WEIGHT_PRECISION - oracleContext.balancerOracleWeight);
        }

        oraclePairPrice = (balancerWeightedPrice + chainlinkWeightedPrice) / 
            BalancerConstants.BALANCER_ORACLE_WEIGHT_PRECISION;
    }

    /// @notice Gets the time-weighted primary token balance for a given bptAmount
    /// @dev Balancer pool needs to be fully initialized with at least 1024 trades
    /// @param poolContext pool context variables
    /// @param oracleContext oracle context variables
    /// @param bptAmount amount of balancer pool lp tokens
    /// @return primaryAmount primary token balance
    function _getTimeWeightedPrimaryBalance(
        TwoTokenPoolContext memory poolContext,
        OracleContext memory oracleContext,
        StrategyContext memory strategyContext,
        uint256 bptAmount
    ) internal view returns (uint256 primaryAmount) {
        // Gets the BPT token price denominated in token index = 0
        uint256 bptPrice = BalancerUtils._getTimeWeightedOraclePrice(
            address(poolContext.basePool.pool),
            IPriceOracle.Variable.BPT_PRICE,
            oracleContext.oracleWindowInSeconds
        );

        uint256 pairPrice = _getOraclePairPrice(poolContext, oracleContext, strategyContext.tradingModule);
        uint256 primaryPrecision = 10 ** poolContext.primaryDecimals;

        if (poolContext.primaryIndex == 0) {
            // Since bptPrice is always denominated in the first token, we can just multiply by
            // the amount in this case. Both bptPrice and bptAmount are in 1e18 but we need to scale
            // this back to the primary token's native precision.
            // underlyingValue = (bptPrice * bptAmount * primaryPrecision) / (1e18 * 1e18)
            primaryAmount = (bptPrice * bptAmount * primaryPrecision) / 
                BalancerConstants.BALANCER_PRECISION_SQUARED;
        } else {
            // The second token in the BPT pool is the price that we want to get. In this case, we need to
            // convert secondaryTokenValue to underlyingValue using the pairPrice.
            // Both bptPrice and bptAmount are in 1e18
            uint256 secondaryAmount = (bptPrice * bptAmount) / BalancerConstants.BALANCER_PRECISION;

            // And then normalizing to primary token precision we add:
            // PrimaryAmount = (SecondaryAmount * primaryPrecision) / PairPrice
            primaryAmount = (secondaryAmount * primaryPrecision) / pairPrice;
        }
    }

    function _approveBalancerTokens(TwoTokenPoolContext memory poolContext, address bptSpender) internal {
        IERC20(poolContext.primaryToken).checkApprove(address(Deployments.BALANCER_VAULT), type(uint256).max);
        IERC20(poolContext.secondaryToken).checkApprove(address(Deployments.BALANCER_VAULT), type(uint256).max);
        // Allow BPT spender to pull BALANCER_POOL_TOKEN
        IERC20(address(poolContext.basePool.pool)).checkApprove(bptSpender, type(uint256).max);
    }

    /// @notice Trade primary currency for secondary if the trade is specified
    function _tradePrimaryForSecondary(
        TwoTokenPoolContext memory poolContext,
        StrategyContext memory strategyContext,
        bytes memory data
    ) private returns (uint256 primarySold, uint256 secondaryBought) {
        (DepositTradeParams memory params) = abi.decode(data, (DepositTradeParams));

        (primarySold, secondaryBought) = StrategyUtils._executeDynamicTradeExactIn({
            params: params.tradeParams, 
            tradingModule: strategyContext.tradingModule, 
            sellToken: poolContext.primaryToken, 
            buyToken: poolContext.secondaryToken, 
            amount: params.tradeAmount
        });
    }

    function _deposit(
        TwoTokenPoolContext memory poolContext,
        StrategyContext memory strategyContext,
        AuraStakingContext memory stakingContext,
        uint256 deposit,
        DepositParams memory params
    ) internal returns (uint256 strategyTokensMinted) {
        uint256 secondaryAmount;
        if (params.tradeData.length != 0) {
            // Allows users to trade on a different DEX instead of Balancer when joining
            (uint256 primarySold, uint256 secondaryBought) = _tradePrimaryForSecondary({
                poolContext: poolContext,
                strategyContext: strategyContext,
                data: params.tradeData
            });
            deposit -= primarySold;
            secondaryAmount = secondaryBought;
        }

        uint256 bptMinted = poolContext._joinPoolAndStake({
            strategyContext: strategyContext,
            stakingContext: stakingContext,
            primaryAmount: deposit,
            secondaryAmount: secondaryAmount,
            minBPT: params.minBPT
        });

        strategyTokensMinted = strategyContext._convertBPTClaimToStrategyTokens(bptMinted);

        // Update global supply count
        strategyContext.vaultState.totalStrategyTokenGlobal += strategyTokensMinted.toUint80();
        strategyContext.vaultState.setStrategyVaultState(); 
    }

    function _sellSecondaryBalance(
        TwoTokenPoolContext memory poolContext,
        StrategyContext memory strategyContext,
        RedeemParams memory params,
        uint256 secondaryBalance
    ) private returns (uint256 primaryPurchased) {
        (DynamicTradeParams memory tradeParams) = abi.decode(
            params.secondaryTradeParams, (DynamicTradeParams)
        );

        ( /*uint256 amountSold */, primaryPurchased) = 
            StrategyUtils._executeDynamicTradeExactIn({
                params: tradeParams,
                tradingModule: strategyContext.tradingModule,
                sellToken: poolContext.secondaryToken,
                buyToken: poolContext.primaryToken,
                amount: secondaryBalance
            });
    }

    function _redeem(
        TwoTokenPoolContext memory poolContext,
        StrategyContext memory strategyContext,
        AuraStakingContext memory stakingContext,
        address account,
        uint256 strategyTokens,
        uint256 maturity,
        RedeemParams memory params
    ) internal returns (uint256 finalPrimaryBalance) {
        uint256 bptClaim = strategyContext._convertStrategyTokensToBPTClaim(strategyTokens);

        if (bptClaim == 0) return 0;

        // Underlying token balances from exiting the pool
        (uint256 primaryBalance, uint256 secondaryBalance)
            = _unstakeAndExitPool(
                poolContext, stakingContext, bptClaim, params.minPrimary, params.minSecondary
            );

        finalPrimaryBalance = primaryBalance;
        if (secondaryBalance > 0) {
            uint256 primaryPurchased = _sellSecondaryBalance(
                poolContext, strategyContext, params, secondaryBalance
            );

            finalPrimaryBalance += primaryPurchased;
        }

        // Update global strategy token balance
        strategyContext.vaultState.totalStrategyTokenGlobal -= strategyTokens.toUint80();
        strategyContext.vaultState.setStrategyVaultState(); 
    }

    function _joinPoolAndStake(
        TwoTokenPoolContext memory poolContext,
        StrategyContext memory strategyContext,
        AuraStakingContext memory stakingContext,
        uint256 primaryAmount,
        uint256 secondaryAmount,
        uint256 minBPT
    ) internal returns (uint256 bptMinted) {
        // prettier-ignore
        PoolParams memory poolParams = poolContext._getPoolParams( 
            primaryAmount, 
            secondaryAmount,
            true // isJoin
        );

        bptMinted = BalancerUtils._joinPoolExactTokensIn({
            context: poolContext.basePool,
            params: poolParams,
            minBPT: minBPT
        });

        // Check BPT threshold to make sure our share of the pool is
        // below maxBalancerPoolShare
        uint256 bptThreshold = strategyContext.vaultSettings._bptThreshold(
            poolContext.basePool.pool.totalSupply()
        );
        uint256 bptHeldAfterJoin = strategyContext.totalBPTHeld + bptMinted;
        if (bptHeldAfterJoin > bptThreshold)
            revert Errors.BalancerPoolShareTooHigh(bptHeldAfterJoin, bptThreshold);

        // Transfer token to Aura protocol for boosted staking
        stakingContext.auraBooster.deposit(stakingContext.auraPoolId, bptMinted, true); // stake = true
    }

    function _unstakeAndExitPool(
        TwoTokenPoolContext memory poolContext,
        AuraStakingContext memory stakingContext,
        uint256 bptClaim,
        uint256 minPrimary,
        uint256 minSecondary
    ) internal returns (uint256 primaryBalance, uint256 secondaryBalance) {
        // Withdraw BPT tokens back to the vault for redemption
        stakingContext.auraRewardPool.withdrawAndUnwrap(bptClaim, false); // claimRewards = false

        uint256[] memory exitBalances = BalancerUtils._exitPoolExactBPTIn({
            context: poolContext.basePool,
            params: poolContext._getPoolParams(minPrimary, minSecondary, false), // isJoin = false
            bptExitAmount: bptClaim
        });
        
        (primaryBalance, secondaryBalance) 
            = (exitBalances[poolContext.primaryIndex], exitBalances[poolContext.secondaryIndex]);
    }

    /// @notice We value strategy tokens in terms of the primary balance. The time weighted
    /// primary balance is used in order to prevent pool manipulation.
    /// @param poolContext pool context variables
    /// @param oracleContext oracle context variables
    /// @param strategyTokenAmount amount of strategy tokens
    /// @return underlyingValue underlying value of strategy tokens
    function _convertStrategyToUnderlying(
        TwoTokenPoolContext memory poolContext,
        StrategyContext memory strategyContext,
        OracleContext memory oracleContext,
        uint256 strategyTokenAmount
    ) internal view returns (int256 underlyingValue) {
        
        uint256 bptClaim 
            = strategyContext._convertStrategyTokensToBPTClaim(strategyTokenAmount);

        underlyingValue 
            = poolContext._getTimeWeightedPrimaryBalance(oracleContext, strategyContext, bptClaim).toInt();
    }
}

// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.7.6;

interface IStrategyVault {

    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function strategy() external view returns (bytes4 strategyId);

    // Tells a vault to deposit some amount of tokens from Notional and mint strategy tokens with it.
    function depositFromNotional(
        address account,
        uint256 depositAmount,
        uint256 maturity,
        bytes calldata data
    ) external payable returns (uint256 strategyTokensMinted);

    // Tells a vault to redeem some amount of strategy tokens from Notional and transfer the resulting asset cash
    function redeemFromNotional(
        address account,
        address receiver,
        uint256 strategyTokens,
        uint256 maturity,
        uint256 underlyingToRepayDebt,
        bytes calldata data
    ) external returns (uint256 transferToReceiver);

    function convertStrategyToUnderlying(
        address account,
        uint256 strategyTokens,
        uint256 maturity
    ) external view returns (int256 underlyingValue);

    function repaySecondaryBorrowCallback(
        address token,
        uint256 underlyingRequired,
        bytes calldata data
    ) external returns (bytes memory returnData);
}

// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.7.6;
pragma abicoder v2;

import {
    VaultConfigStorage,
    VaultConfig,
    VaultState,
    VaultAccount
} from "../../contracts/global/Types.sol";

interface IVaultAction {
    /// @notice Emitted when a new vault is listed or updated
    event VaultUpdated(address indexed vault, bool enabled, uint80 maxPrimaryBorrowCapacity);
    /// @notice Emitted when a vault's status is updated
    event VaultPauseStatus(address indexed vault, bool enabled);
    /// @notice Emitted when a secondary currency borrow capacity is updated
    event VaultUpdateSecondaryBorrowCapacity(address indexed vault, uint16 indexed currencyId, uint80 maxSecondaryBorrowCapacity);
    /// @notice Emitted when a vault has a shortfall upon settlement
    event VaultShortfall(address indexed vault, uint16 indexed currencyId, uint256 indexed maturity, int256 shortfall);
    /// @notice Emitted when a vault has an insolvency that cannot be covered by the
    /// cash reserve
    event ProtocolInsolvency(address indexed vault, uint16 indexed currencyId, uint256 indexed maturity, int256 shortfall);
    /// @notice Emitted when a vault fee is accrued via borrowing (denominated in asset cash)
    event VaultFeeAccrued(address indexed vault, uint16 indexed currencyId, uint256 indexed maturity, int256 reserveFee, int256 nTokenFee);
    /// @notice Emitted when the borrow capacity on a vault changes
    event VaultBorrowCapacityChange(address indexed vault, uint16 indexed currencyId, uint256 totalUsedBorrowCapacity);

    /// @notice Emitted when a vault executes a secondary borrow
    event VaultSecondaryBorrow(
        address indexed vault,
        address indexed account,
        uint16 indexed currencyId,
        uint256 maturity,
        uint256 debtSharesMinted,
        uint256 fCashBorrowed
    );

    /// @notice Emitted when a vault repays a secondary borrow
    event VaultRepaySecondaryBorrow(
        address indexed vault,
        address indexed account,
        uint16 indexed currencyId,
        uint256 maturity,
        uint256 debtSharesRepaid,
        uint256 fCashLent
    );

    /// @notice Emitted when secondary borrows are snapshot prior to settlement
    event VaultSecondaryBorrowSnapshot(
        address indexed vault,
        uint16 indexed currencyId,
        uint256 indexed maturity,
        int256 totalfCashBorrowedInPrimarySnapshot,
        int256 exchangeRate
    );

    /// @notice Emitted when a vault settles assets
    event VaultSettledAssetsRemaining(
        address indexed vault,
        uint256 indexed maturity,
        int256 remainingAssetCash,
        uint256 remainingStrategyTokens
    );

    event VaultStateUpdate(
        address indexed vault,
        uint256 indexed maturity,
        int256 totalfCash,
        uint256 totalAssetCash,
        uint256 totalStrategyTokens,
        uint256 totalVaultShares
    );

    event VaultSettled(
        address indexed vault,
        uint256 indexed maturity,
        int256 totalfCash,
        uint256 totalAssetCash,
        uint256 totalStrategyTokens,
        uint256 totalVaultShares,
        int256 strategyTokenValue
    );
    
    event VaultRedeemStrategyToken(
        address indexed vault,
        uint256 indexed maturity,
        int256 assetCashReceived,
        uint256 strategyTokensRedeemed
    );
    
    event VaultMintStrategyToken(
        address indexed vault,
        uint256 indexed maturity,
        uint256 assetCashDeposited,
        uint256 strategyTokensMinted
    );

    /** Vault Action Methods */

    /// @notice Governance only method to whitelist a particular vault
    function updateVault(
        address vaultAddress,
        VaultConfigStorage calldata vaultConfig,
        uint80 maxPrimaryBorrowCapacity
    ) external;

    /// @notice Governance only method to pause a particular vault
    function setVaultPauseStatus(
        address vaultAddress,
        bool enable
    ) external;

    /// @notice Governance only method to force a particular vault to deleverage
    function reduceMaxBorrowCapacity(
        address vaultAddress,
        uint80 maxVaultBorrowCapacity,
        uint256 maturity,
        uint256 strategyTokensToRedeem,
        bytes calldata vaultData
    ) external;

    /// @notice Governance only method to update a vault's secondary borrow capacity
    function updateSecondaryBorrowCapacity(
        address vaultAddress,
        uint16 secondaryCurrencyId,
        uint80 maxBorrowCapacity
    ) external;

    /// @notice Vault authenticated method that takes asset cash from the pool and mints strategy tokens
    function depositVaultCashToStrategyTokens(
        uint256 maturity,
        uint256 assetCashToDepositExternal,
        bytes calldata vaultData
    ) external;

    /// @notice Vault authenticated method that takes strategy tokens and mints asset cash to the pool
    function redeemStrategyTokensToCash(
        uint256 maturity,
        uint256 strategyTokensToRedeem,
        bytes calldata vaultData
    ) external returns (
        int256 assetCashRequiredToSettle,
        int256 underlyingCashRequiredToSettle
    );

    function borrowSecondaryCurrencyToVault(
        address account,
        uint256 maturity,
        uint256[2] calldata fCashToBorrow,
        uint32[2] calldata maxBorrowRate,
        uint32[2] calldata minRollLendRate
    ) external returns (uint256[2] memory underlyingTokensTransferred);

    function repaySecondaryCurrencyFromVault(
        address account,
        uint16 currencyId,
        uint256 maturity,
        uint256 fCashToRepay,
        uint32 slippageLimit,
        bytes calldata callbackData
    ) external returns (bytes memory returnData);

    function initiateSecondaryBorrowSettlement(uint256 maturity)
        external returns (uint256[2] memory secondaryBorrowSnapshot);

    /// @notice Non-authenticated method that will set settlement values for a vault so that
    /// account holders can withdraw matured assets.
    function settleVault(address vault, uint256 maturity) external;

    /// @notice View method to get vault configuration
    function getVaultConfig(address vault) external view returns (VaultConfig memory vaultConfig);

    function getBorrowCapacity(address vault, uint16 currencyId)
        external view returns (uint256 totalUsedBorrowCapacity, uint256 maxBorrowCapacity);

    function getSecondaryBorrow(address vault, uint16 currencyId, uint256 maturity) 
        external view returns (
            uint256 totalfCashBorrowed,
            uint256 totalAccountDebtShares,
            uint256 totalfCashBorrowedInPrimarySnapshot
        );

    /// @notice View method to get vault state
    function getVaultState(address vault, uint256 maturity) external view returns (VaultState memory vaultState);

    /// @notice View method to get the current amount of cash remaining to settle the vault
    function getCashRequiredToSettle(
        address vault,
        uint256 maturity
    ) external view returns (
        int256 assetCashRequiredToSettle,
        int256 underlyingCashRequiredToSettle
    );
}

interface IVaultAccountAction {

    event VaultEnterPosition(
        address indexed vault,
        address indexed account,
        uint256 indexed maturity,
        uint256 fCashBorrowed
    );

    event VaultRollPosition(
        address indexed vault,
        address indexed account,
        uint256 indexed newMaturity,
        uint256 fCashBorrowed
    );

    event VaultExitPostMaturity(
        address indexed vault,
        address indexed account,
        uint256 indexed maturity
    );

    event VaultExitPreMaturity(
        address indexed vault,
        address indexed account,
        uint256 indexed maturity,
        uint256 fCashToLend,
        uint256 vaultSharesToRedeem
    );

    event VaultDeleverageAccount(
        address indexed vault,
        address indexed account,
        uint256 vaultSharesToLiquidator,
        int256 fCashRepaid
    );

    event VaultLiquidatorProfit(
        address indexed vault,
        address indexed account,
        address indexed liquidator,
        uint256 vaultSharesToLiquidator,
        bool transferSharesToLiquidator
    );

    event VaultEnterMaturity(
        address indexed vault,
        uint256 indexed maturity,
        address indexed account,
        uint256 underlyingTokensTransferred,
        uint256 strategyTokenDeposited,
        uint256 vaultSharesMinted
    );
    
    /**
     * @notice Borrows a specified amount of fCash in the vault's borrow currency and deposits it
     * all plus the depositAmountExternal into the vault to mint strategy tokens.
     *
     * @param account the address that will enter the vault
     * @param vault the vault to enter
     * @param depositAmountExternal some amount of additional collateral in the borrowed currency
     * to be transferred to vault
     * @param maturity the maturity to borrow at
     * @param fCash amount to borrow
     * @param maxBorrowRate maximum interest rate to borrow at
     * @param vaultData additional data to pass to the vault contract
     */
    function enterVault(
        address account,
        address vault,
        uint256 depositAmountExternal,
        uint256 maturity,
        uint256 fCash,
        uint32 maxBorrowRate,
        bytes calldata vaultData
    ) external payable returns (uint256 strategyTokensAdded);

    /**
     * @notice Re-enters the vault at a longer dated maturity. The account's existing borrow
     * position will be closed and a new borrow position at the specified maturity will be
     * opened. All strategy token holdings will be rolled forward.
     *
     * @param account the address that will reenter the vault
     * @param vault the vault to reenter
     * @param fCashToBorrow amount of fCash to borrow in the next maturity
     * @param maturity new maturity to borrow at
     */
    function rollVaultPosition(
        address account,
        address vault,
        uint256 fCashToBorrow,
        uint256 maturity,
        uint32 minLendRate,
        uint32 maxBorrowRate,
        bytes calldata enterVaultData
    ) external returns (uint256 strategyTokensAdded);

    /**
     * @notice Prior to maturity, allows an account to withdraw their position from the vault. Will
     * redeem some number of vault shares to the borrow currency and close the borrow position by
     * lending `fCashToLend`. Any shortfall in cash from lending will be transferred from the account,
     * any excess profits will be transferred to the account.
     *
     * Post maturity, will net off the account's debt against vault cash balances and redeem all remaining
     * strategy tokens back to the borrowed currency and transfer the profits to the account.
     *
     * @param account the address that will exit the vault
     * @param vault the vault to enter
     * @param vaultSharesToRedeem amount of vault tokens to exit, only relevant when exiting pre-maturity
     * @param fCashToLend amount of fCash to lend
     * @param minLendRate the minimum rate to lend at
     * @param exitVaultData passed to the vault during exit
     * @return underlyingToReceiver amount of underlying tokens returned to the receiver on exit
     */
    function exitVault(
        address account,
        address vault,
        address receiver,
        uint256 vaultSharesToRedeem,
        uint256 fCashToLend,
        uint32 minLendRate,
        bytes calldata exitVaultData
    ) external payable returns (uint256 underlyingToReceiver);

    /**
     * @notice If an account is below the minimum collateral ratio, this method wil deleverage (liquidate)
     * that account. `depositAmountExternal` in the borrow currency will be transferred from the liquidator
     * and used to offset the account's debt position. The liquidator will receive either vaultShares or
     * cash depending on the vault's configuration.
     * @param account the address that will exit the vault
     * @param vault the vault to enter
     * @param liquidator the address that will receive profits from liquidation
     * @param depositAmountExternal amount of cash to deposit
     * @param transferSharesToLiquidator transfers the shares to the liquidator instead of redeeming them
     * @param redeemData calldata sent to the vault when redeeming liquidator profits
     * @return profitFromLiquidation amount of vaultShares or cash received from liquidation
     */
    function deleverageAccount(
        address account,
        address vault,
        address liquidator,
        uint256 depositAmountExternal,
        bool transferSharesToLiquidator,
        bytes calldata redeemData
    ) external returns (uint256 profitFromLiquidation);

    function getVaultAccount(address account, address vault) external view returns (VaultAccount memory);
    function getVaultAccountDebtShares(address account, address vault) external view returns (
        uint256 debtSharesMaturity,
        uint256[2] memory accountDebtShares,
        uint256 accountStrategyTokens
    );
    function getVaultAccountCollateralRatio(address account, address vault) external view returns (
        int256 collateralRatio,
        int256 minCollateralRatio,
        int256 maxLiquidatorDepositAssetCash,
        uint256 vaultSharesToLiquidator
    );
}

interface IVaultController is IVaultAccountAction, IVaultAction {}

pragma solidity 0.8.15;

interface IAuraRewardPool {
    function withdrawAndUnwrap(uint256 amount, bool claim) external returns(bool);
    function getReward(address _account, bool _claimExtras) external returns(bool);
    function balanceOf(address _account) external view returns(uint256);
    function pid() external view returns(uint256);
    function operator() external view returns(address);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "../../contracts/global/Types.sol";
import "./INTokenAction.sol";
import "./nERC1155Interface.sol";
import "./NotionalGovernance.sol";
import "./NotionalCalculations.sol";
import "./NotionalViews.sol";
import "./NotionalTreasury.sol";
import {IVaultController} from "./IVaultController.sol";

interface NotionalProxy is
    INTokenAction,
    nERC1155Interface,
    NotionalGovernance,
    NotionalTreasury,
    NotionalCalculations,
    NotionalViews,
    IVaultController
{
    /** User trading events */
    event CashBalanceChange(
        address indexed account,
        uint16 indexed currencyId,
        int256 netCashChange
    );
    event nTokenSupplyChange(
        address indexed account,
        uint16 indexed currencyId,
        int256 tokenSupplyChange
    );
    event MarketsInitialized(uint16 currencyId);
    event SweepCashIntoMarkets(uint16 currencyId, int256 cashIntoMarkets);
    event SettledCashDebt(
        address indexed settledAccount,
        uint16 indexed currencyId,
        address indexed settler,
        int256 amountToSettleAsset,
        int256 fCashAmount
    );
    event nTokenResidualPurchase(
        uint16 indexed currencyId,
        uint40 indexed maturity,
        address indexed purchaser,
        int256 fCashAmountToPurchase,
        int256 netAssetCashNToken
    );
    event LendBorrowTrade(
        address indexed account,
        uint16 indexed currencyId,
        uint40 maturity,
        int256 netAssetCash,
        int256 netfCash
    );
    event AddRemoveLiquidity(
        address indexed account,
        uint16 indexed currencyId,
        uint40 maturity,
        int256 netAssetCash,
        int256 netfCash,
        int256 netLiquidityTokens
    );

    /// @notice Emitted once when incentives are migrated
    event IncentivesMigrated(
        uint16 currencyId,
        uint256 migrationEmissionRate,
        uint256 finalIntegralTotalSupply,
        uint256 migrationTime
    );

    /// @notice Emitted when reserve fees are accrued
    event ReserveFeeAccrued(uint16 indexed currencyId, int256 fee);
    /// @notice Emitted whenever an account context has updated
    event AccountContextUpdate(address indexed account);
    /// @notice Emitted when an account has assets that are settled
    event AccountSettled(address indexed account);
    /// @notice Emitted when an asset rate is settled
    event SetSettlementRate(uint256 indexed currencyId, uint256 indexed maturity, uint128 rate);

    /* Liquidation Events */
    event LiquidateLocalCurrency(
        address indexed liquidated,
        address indexed liquidator,
        uint16 localCurrencyId,
        int256 netLocalFromLiquidator
    );

    event LiquidateCollateralCurrency(
        address indexed liquidated,
        address indexed liquidator,
        uint16 localCurrencyId,
        uint16 collateralCurrencyId,
        int256 netLocalFromLiquidator,
        int256 netCollateralTransfer,
        int256 netNTokenTransfer
    );

    event LiquidatefCashEvent(
        address indexed liquidated,
        address indexed liquidator,
        uint16 localCurrencyId,
        uint16 fCashCurrency,
        int256 netLocalFromLiquidator,
        uint256[] fCashMaturities,
        int256[] fCashNotionalTransfer
    );

    /** UUPS Upgradeable contract calls */
    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    function getImplementation() external view returns (address);

    function owner() external view returns (address);

    function pauseRouter() external view returns (address);

    function pauseGuardian() external view returns (address);

    /** Initialize Markets Action */
    function initializeMarkets(uint16 currencyId, bool isFirstInit) external;

    function sweepCashIntoMarkets(uint16 currencyId) external;

    /** Redeem nToken Action */
    function nTokenRedeem(
        address redeemer,
        uint16 currencyId,
        uint96 tokensToRedeem_,
        bool sellTokenAssets,
        bool acceptResidualAssets
    ) external returns (int256);

    /** Account Action */
    function enableBitmapCurrency(uint16 currencyId) external;

    function settleAccount(address account) external;

    function depositUnderlyingToken(
        address account,
        uint16 currencyId,
        uint256 amountExternalPrecision
    ) external payable returns (uint256);

    function depositAssetToken(
        address account,
        uint16 currencyId,
        uint256 amountExternalPrecision
    ) external returns (uint256);

    function withdraw(
        uint16 currencyId,
        uint88 amountInternalPrecision,
        bool redeemToUnderlying
    ) external returns (uint256);

    /** Batch Action */
    function batchBalanceAction(address account, BalanceAction[] calldata actions) external payable;

    function batchBalanceAndTradeAction(address account, BalanceActionWithTrades[] calldata actions)
        external
        payable;

    function batchBalanceAndTradeActionWithCallback(
        address account,
        BalanceActionWithTrades[] calldata actions,
        bytes calldata callbackData
    ) external payable;

    function batchLend(address account, BatchLend[] calldata actions) external;

    /** Liquidation Action */
    function calculateLocalCurrencyLiquidation(
        address liquidateAccount,
        uint16 localCurrency,
        uint96 maxNTokenLiquidation
    ) external returns (int256, int256);

    function liquidateLocalCurrency(
        address liquidateAccount,
        uint16 localCurrency,
        uint96 maxNTokenLiquidation
    ) external returns (int256, int256);

    function calculateCollateralCurrencyLiquidation(
        address liquidateAccount,
        uint16 localCurrency,
        uint16 collateralCurrency,
        uint128 maxCollateralLiquidation,
        uint96 maxNTokenLiquidation
    )
        external
        returns (
            int256,
            int256,
            int256
        );

    function liquidateCollateralCurrency(
        address liquidateAccount,
        uint16 localCurrency,
        uint16 collateralCurrency,
        uint128 maxCollateralLiquidation,
        uint96 maxNTokenLiquidation,
        bool withdrawCollateral,
        bool redeemToUnderlying
    )
        external
        returns (
            int256,
            int256,
            int256
        );

    function calculatefCashLocalLiquidation(
        address liquidateAccount,
        uint16 localCurrency,
        uint256[] calldata fCashMaturities,
        uint256[] calldata maxfCashLiquidateAmounts
    ) external returns (int256[] memory, int256);

    function liquidatefCashLocal(
        address liquidateAccount,
        uint16 localCurrency,
        uint256[] calldata fCashMaturities,
        uint256[] calldata maxfCashLiquidateAmounts
    ) external returns (int256[] memory, int256);

    function calculatefCashCrossCurrencyLiquidation(
        address liquidateAccount,
        uint16 localCurrency,
        uint16 fCashCurrency,
        uint256[] calldata fCashMaturities,
        uint256[] calldata maxfCashLiquidateAmounts
    ) external returns (int256[] memory, int256);

    function liquidatefCashCrossCurrency(
        address liquidateAccount,
        uint16 localCurrency,
        uint16 fCashCurrency,
        uint256[] calldata fCashMaturities,
        uint256[] calldata maxfCashLiquidateAmounts
    ) external returns (int256[] memory, int256);
}

pragma solidity 0.8.15;

interface IAuraBooster {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function stakerRewards() external view returns(address);
}

pragma solidity 0.8.15;

interface IBalancerMinter {
    function mint(address gauge) external;
    function getBalancerToken() external returns (address);
}

pragma solidity 0.8.15;

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

interface IBalancerVault {
    enum PoolSpecialization {
        GENERAL,
        MINIMAL_SWAP_INFO,
        TWO_TOKEN
    }
    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT,
        MANAGEMENT_FEE_TOKENS_OUT // for ManagedPool
    }

    /**
     * @dev Returns a Pool's contract address and specialization setting.
     */
    function getPool(bytes32 poolId)
        external
        view
        returns (address, PoolSpecialization);

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable;

    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external;

    struct ExitPoolRequest {
        IAsset[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256);

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external payable returns (int256[] memory);

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );

    function flashLoan(
        address recipient, 
        address[] calldata tokens, 
        uint256[] calldata amounts, 
        bytes calldata userData
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILiquidityGauge is IERC20 {
    function deposit(uint256 value) external;

    function deposit(uint256 _value, address _addr, bool _claim_rewards) external;

    function withdraw(uint256 value, bool claim_rewards) external;

    function claim_rewards() external;

    // curve & balancer use lp_token()
    function lp_token() external view returns (address);

    // angle use staking_token()
    function staking_token() external view returns (address);

    function reward_tokens(uint256 i) external view returns (address token);

    function reward_count() external view returns (uint256 nTokens);

    function user_checkpoint(address addr) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../chainlink/AggregatorV2V3Interface.sol";

enum DexId {
    _UNUSED,
    UNISWAP_V2,
    UNISWAP_V3,
    ZERO_EX,
    BALANCER_V2,
    CURVE,
    NOTIONAL_VAULT
}

enum TradeType {
    EXACT_IN_SINGLE,
    EXACT_OUT_SINGLE,
    EXACT_IN_BATCH,
    EXACT_OUT_BATCH
}

struct Trade {
    TradeType tradeType;
    address sellToken;
    address buyToken;
    uint256 amount;
    /// minBuyAmount or maxSellAmount
    uint256 limit;
    uint256 deadline;
    bytes exchangeData;
}

error InvalidTrade();

interface ITradingModule {
    event TradeExecuted(
        address indexed sellToken,
        address indexed buyToken,
        uint256 sellAmount,
        uint256 buyAmount
    );

    event PriceOracleUpdated(address token, address oracle);
    event MaxOracleFreshnessUpdated(uint32 currentValue, uint32 newValue);

    function getExecutionData(uint16 dexId, address from, Trade calldata trade)
        external view returns (
            address spender,
            address target,
            uint256 value,
            bytes memory params
        );

    function setPriceOracle(address token, AggregatorV2V3Interface oracle) external;

    function getOraclePrice(address inToken, address outToken)
        external view returns (int256 answer, int256 decimals);

    function executeTrade(
        uint16 dexId,
        Trade calldata trade
    ) external returns (uint256 amountSold, uint256 amountBought);

    function executeTradeWithDynamicSlippage(
        uint16 dexId,
        Trade memory trade,
        uint32 dynamicSlippageLimit
    ) external returns (uint256 amountSold, uint256 amountBought);

    function getLimitAmount(
        TradeType tradeType,
        address sellToken,
        address buyToken,
        uint256 amount,
        uint32 slippageLimit
    ) external view returns (uint256 limitAmount);
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.15;
pragma abicoder v2;

/**
 * @dev Interface for querying historical data from a Pool that can be used as a Price Oracle.
 *
 * This lets third parties retrieve average prices of tokens held by a Pool over a given period of time, as well as the
 * price of the Pool share token (BPT) and invariant. Since the invariant is a sensible measure of Pool liquidity, it
 * can be used to compare two different price sources, and choose the most liquid one.
 *
 * Once the oracle is fully initialized, all queries are guaranteed to succeed as long as they require no data that
 * is not older than the largest safe query window.
 */
interface IPriceOracle {
    // The three values that can be queried:
    //
    // - PAIR_PRICE: the price of the tokens in the Pool, expressed as the price of the second token in units of the
    //   first token. For example, if token A is worth $2, and token B is worth $4, the pair price will be 2.0.
    //   Note that the price is computed *including* the tokens decimals. This means that the pair price of a Pool with
    //   DAI and USDC will be close to 1.0, despite DAI having 18 decimals and USDC 6.
    //
    // - BPT_PRICE: the price of the Pool share token (BPT), in units of the first token.
    //   Note that the price is computed *including* the tokens decimals. This means that the BPT price of a Pool with
    //   USDC in which BPT is worth $5 will be 5.0, despite the BPT having 18 decimals and USDC 6.
    //
    // - INVARIANT: the value of the Pool's invariant, which serves as a measure of its liquidity.
    enum Variable { PAIR_PRICE, BPT_PRICE, INVARIANT }

    /**
     * @dev Returns the time average weighted price corresponding to each of `queries`. Prices are represented as 18
     * decimal fixed point values.
     */
    function getTimeWeightedAverage(OracleAverageQuery[] memory queries)
        external
        view
        returns (uint256[] memory results);

    /**
     * @dev Returns latest sample of `variable`. Prices are represented as 18 decimal fixed point values.
     */
    function getLatest(Variable variable) external view returns (uint256);

    /**
     * @dev Information for a Time Weighted Average query.
     *
     * Each query computes the average over a window of duration `secs` seconds that ended `ago` seconds ago. For
     * example, the average over the past 30 minutes is computed by settings secs to 1800 and ago to 0. If secs is 1800
     * and ago is 1800 as well, the average between 60 and 30 minutes ago is computed instead.
     */
    struct OracleAverageQuery {
        Variable variable;
        uint256 secs;
        uint256 ago;
    }

    /**
     * @dev Returns largest time window that can be safely queried, where 'safely' means the Oracle is guaranteed to be
     * able to produce a result and not revert.
     *
     * If a query has a non-zero `ago` value, then `secs + ago` (the oldest point in time) must be smaller than this
     * value for 'safe' queries.
     */
    function getLargestSafeQueryWindow() external view returns (uint256);

    /**
     * @dev Returns the accumulators corresponding to each of `queries`.
     */
    function getPastAccumulators(OracleAccumulatorQuery[] memory queries)
        external
        view
        returns (int256[] memory results);

    /**
     * @dev Information for an Accumulator query.
     *
     * Each query estimates the accumulator at a time `ago` seconds ago.
     */
    struct OracleAccumulatorQuery {
        Variable variable;
        uint256 ago;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "../../interfaces/chainlink/AggregatorV2V3Interface.sol";
import "../../interfaces/notional/AssetRateAdapter.sol";

/// @notice Different types of internal tokens
///  - UnderlyingToken: underlying asset for a cToken (except for Ether)
///  - cToken: Compound interest bearing token
///  - cETH: Special handling for cETH tokens
///  - Ether: the one and only
///  - NonMintable: tokens that do not have an underlying (therefore not cTokens)
///  - aToken: Aave interest bearing tokens
enum TokenType {
    UnderlyingToken,
    cToken,
    cETH,
    Ether,
    NonMintable,
    aToken
}

/// @notice Specifies the different trade action types in the system. Each trade action type is
/// encoded in a tightly packed bytes32 object. Trade action type is the first big endian byte of the
/// 32 byte trade action object. The schemas for each trade action type are defined below.
enum TradeActionType {
    // (uint8 TradeActionType, uint8 MarketIndex, uint88 fCashAmount, uint32 minImpliedRate, uint120 unused)
    Lend,
    // (uint8 TradeActionType, uint8 MarketIndex, uint88 fCashAmount, uint32 maxImpliedRate, uint128 unused)
    Borrow,
    // (uint8 TradeActionType, uint8 MarketIndex, uint88 assetCashAmount, uint32 minImpliedRate, uint32 maxImpliedRate, uint88 unused)
    AddLiquidity,
    // (uint8 TradeActionType, uint8 MarketIndex, uint88 tokenAmount, uint32 minImpliedRate, uint32 maxImpliedRate, uint88 unused)
    RemoveLiquidity,
    // (uint8 TradeActionType, uint32 Maturity, int88 fCashResidualAmount, uint128 unused)
    PurchaseNTokenResidual,
    // (uint8 TradeActionType, address CounterpartyAddress, int88 fCashAmountToSettle)
    SettleCashDebt
}

/// @notice Specifies different deposit actions that can occur during BalanceAction or BalanceActionWithTrades
enum DepositActionType {
    // No deposit action
    None,
    // Deposit asset cash, depositActionAmount is specified in asset cash external precision
    DepositAsset,
    // Deposit underlying tokens that are mintable to asset cash, depositActionAmount is specified in underlying token
    // external precision
    DepositUnderlying,
    // Deposits specified asset cash external precision amount into an nToken and mints the corresponding amount of
    // nTokens into the account
    DepositAssetAndMintNToken,
    // Deposits specified underlying in external precision, mints asset cash, and uses that asset cash to mint nTokens
    DepositUnderlyingAndMintNToken,
    // Redeems an nToken balance to asset cash. depositActionAmount is specified in nToken precision. Considered a deposit action
    // because it deposits asset cash into an account. If there are fCash residuals that cannot be sold off, will revert.
    RedeemNToken,
    // Converts specified amount of asset cash balance already in Notional to nTokens. depositActionAmount is specified in
    // Notional internal 8 decimal precision.
    ConvertCashToNToken
}

/// @notice Used internally for PortfolioHandler state
enum AssetStorageState {
    NoChange,
    Update,
    Delete,
    RevertIfStored
}

/****** Calldata objects ******/

/// @notice Defines a batch lending action
struct BatchLend {
    uint16 currencyId;
    // True if the contract should try to transfer underlying tokens instead of asset tokens
    bool depositUnderlying;
    // Array of tightly packed 32 byte objects that represent trades. See TradeActionType documentation
    bytes32[] trades;
}

/// @notice Defines a balance action for batchAction
struct BalanceAction {
    // Deposit action to take (if any)
    DepositActionType actionType;
    uint16 currencyId;
    // Deposit action amount must correspond to the depositActionType, see documentation above.
    uint256 depositActionAmount;
    // Withdraw an amount of asset cash specified in Notional internal 8 decimal precision
    uint256 withdrawAmountInternalPrecision;
    // If set to true, will withdraw entire cash balance. Useful if there may be an unknown amount of asset cash
    // residual left from trading.
    bool withdrawEntireCashBalance;
    // If set to true, will redeem asset cash to the underlying token on withdraw.
    bool redeemToUnderlying;
}

/// @notice Defines a balance action with a set of trades to do as well
struct BalanceActionWithTrades {
    DepositActionType actionType;
    uint16 currencyId;
    uint256 depositActionAmount;
    uint256 withdrawAmountInternalPrecision;
    bool withdrawEntireCashBalance;
    bool redeemToUnderlying;
    // Array of tightly packed 32 byte objects that represent trades. See TradeActionType documentation
    bytes32[] trades;
}

/****** In memory objects ******/
/// @notice Internal object that represents settled cash balances
struct SettleAmount {
    uint256 currencyId;
    int256 netCashChange;
}

/// @notice Internal object that represents a token
struct Token {
    address tokenAddress;
    bool hasTransferFee;
    int256 decimals;
    TokenType tokenType;
    uint256 maxCollateralBalance;
}

/// @notice Internal object that represents an nToken portfolio
struct nTokenPortfolio {
    CashGroupParameters cashGroup;
    PortfolioState portfolioState;
    int256 totalSupply;
    int256 cashBalance;
    uint256 lastInitializedTime;
    bytes6 parameters;
    address tokenAddress;
}

/// @notice Internal object used during liquidation
struct LiquidationFactors {
    address account;
    // Aggregate free collateral of the account denominated in ETH underlying, 8 decimal precision
    int256 netETHValue;
    // Amount of net local currency asset cash before haircuts and buffers available
    int256 localAssetAvailable;
    // Amount of net collateral currency asset cash before haircuts and buffers available
    int256 collateralAssetAvailable;
    // Haircut value of nToken holdings denominated in asset cash, will be local or collateral nTokens based
    // on liquidation type
    int256 nTokenHaircutAssetValue;
    // nToken parameters for calculating liquidation amount
    bytes6 nTokenParameters;
    // ETH exchange rate from local currency to ETH
    ETHRate localETHRate;
    // ETH exchange rate from collateral currency to ETH
    ETHRate collateralETHRate;
    // Asset rate for the local currency, used in cross currency calculations to calculate local asset cash required
    AssetRateParameters localAssetRate;
    // Used during currency liquidations if the account has liquidity tokens
    CashGroupParameters collateralCashGroup;
    // Used during currency liquidations if it is only a calculation, defaults to false
    bool isCalculation;
}

/// @notice Internal asset array portfolio state
struct PortfolioState {
    // Array of currently stored assets
    PortfolioAsset[] storedAssets;
    // Array of new assets to add
    PortfolioAsset[] newAssets;
    uint256 lastNewAssetIndex;
    // Holds the length of stored assets after accounting for deleted assets
    uint256 storedAssetLength;
}

/// @notice In memory ETH exchange rate used during free collateral calculation.
struct ETHRate {
    // The decimals (i.e. 10^rateDecimalPlaces) of the exchange rate, defined by the rate oracle
    int256 rateDecimals;
    // The exchange rate from base to ETH (if rate invert is required it is already done)
    int256 rate;
    // Amount of buffer as a multiple with a basis of 100 applied to negative balances.
    int256 buffer;
    // Amount of haircut as a multiple with a basis of 100 applied to positive balances
    int256 haircut;
    // Liquidation discount as a multiple with a basis of 100 applied to the exchange rate
    // as an incentive given to liquidators.
    int256 liquidationDiscount;
}

/// @notice Internal object used to handle balance state during a transaction
struct BalanceState {
    uint16 currencyId;
    // Cash balance stored in balance state at the beginning of the transaction
    int256 storedCashBalance;
    // nToken balance stored at the beginning of the transaction
    int256 storedNTokenBalance;
    // The net cash change as a result of asset settlement or trading
    int256 netCashChange;
    // Net asset transfers into or out of the account
    int256 netAssetTransferInternalPrecision;
    // Net token transfers into or out of the account
    int256 netNTokenTransfer;
    // Net token supply change from minting or redeeming
    int256 netNTokenSupplyChange;
    // The last time incentives were claimed for this currency
    uint256 lastClaimTime;
    // Accumulator for incentives that the account no longer has a claim over
    uint256 accountIncentiveDebt;
}

/// @dev Asset rate used to convert between underlying cash and asset cash
struct AssetRateParameters {
    // Address of the asset rate oracle
    AssetRateAdapter rateOracle;
    // The exchange rate from base to quote (if invert is required it is already done)
    int256 rate;
    // The decimals of the underlying, the rate converts to the underlying decimals
    int256 underlyingDecimals;
}

/// @dev Cash group when loaded into memory
struct CashGroupParameters {
    uint16 currencyId;
    uint256 maxMarketIndex;
    AssetRateParameters assetRate;
    bytes32 data;
}

/// @dev A portfolio asset when loaded in memory
struct PortfolioAsset {
    // Asset currency id
    uint256 currencyId;
    uint256 maturity;
    // Asset type, fCash or liquidity token.
    uint256 assetType;
    // fCash amount or liquidity token amount
    int256 notional;
    // Used for managing portfolio asset state
    uint256 storageSlot;
    // The state of the asset for when it is written to storage
    AssetStorageState storageState;
}

/// @dev Market object as represented in memory
struct MarketParameters {
    bytes32 storageSlot;
    uint256 maturity;
    // Total amount of fCash available for purchase in the market.
    int256 totalfCash;
    // Total amount of cash available for purchase in the market.
    int256 totalAssetCash;
    // Total amount of liquidity tokens (representing a claim on liquidity) in the market.
    int256 totalLiquidity;
    // This is the previous annualized interest rate in RATE_PRECISION that the market traded
    // at. This is used to calculate the rate anchor to smooth interest rates over time.
    uint256 lastImpliedRate;
    // Time lagged version of lastImpliedRate, used to value fCash assets at market rates while
    // remaining resistent to flash loan attacks.
    uint256 oracleRate;
    // This is the timestamp of the previous trade
    uint256 previousTradeTime;
}

/****** Storage objects ******/

/// @dev Token object in storage:
///  20 bytes for token address
///  1 byte for hasTransferFee
///  1 byte for tokenType
///  1 byte for tokenDecimals
///  9 bytes for maxCollateralBalance (may not always be set)
struct TokenStorage {
    // Address of the token
    address tokenAddress;
    // Transfer fees will change token deposit behavior
    bool hasTransferFee;
    TokenType tokenType;
    uint8 decimalPlaces;
    // Upper limit on how much of this token the contract can hold at any time
    uint72 maxCollateralBalance;
}

/// @dev Exchange rate object as it is represented in storage, total storage is 25 bytes.
struct ETHRateStorage {
    // Address of the rate oracle
    AggregatorV2V3Interface rateOracle;
    // The decimal places of precision that the rate oracle uses
    uint8 rateDecimalPlaces;
    // True of the exchange rate must be inverted
    bool mustInvert;
    // NOTE: both of these governance values are set with BUFFER_DECIMALS precision
    // Amount of buffer to apply to the exchange rate for negative balances.
    uint8 buffer;
    // Amount of haircut to apply to the exchange rate for positive balances
    uint8 haircut;
    // Liquidation discount in percentage point terms, 106 means a 6% discount
    uint8 liquidationDiscount;
}

/// @dev Asset rate oracle object as it is represented in storage, total storage is 21 bytes.
struct AssetRateStorage {
    // Address of the rate oracle
    AssetRateAdapter rateOracle;
    // The decimal places of the underlying asset
    uint8 underlyingDecimalPlaces;
}

/// @dev Governance parameters for a cash group, total storage is 9 bytes + 7 bytes for liquidity token haircuts
/// and 7 bytes for rate scalars, total of 23 bytes. Note that this is stored packed in the storage slot so there
/// are no indexes stored for liquidityTokenHaircuts or rateScalars, maxMarketIndex is used instead to determine the
/// length.
struct CashGroupSettings {
    // Index of the AMMs on chain that will be made available. Idiosyncratic fCash
    // that is dated less than the longest AMM will be tradable.
    uint8 maxMarketIndex;
    // Time window in 5 minute increments that the rate oracle will be averaged over
    uint8 rateOracleTimeWindow5Min;
    // Total fees per trade, specified in BPS
    uint8 totalFeeBPS;
    // Share of the fees given to the protocol, denominated in percentage
    uint8 reserveFeeShare;
    // Debt buffer specified in 5 BPS increments
    uint8 debtBuffer5BPS;
    // fCash haircut specified in 5 BPS increments
    uint8 fCashHaircut5BPS;
    // If an account has a negative cash balance, it can be settled by incurring debt at the 3 month market. This
    // is the basis points for the penalty rate that will be added the current 3 month oracle rate.
    uint8 settlementPenaltyRate5BPS;
    // If an account has fCash that is being liquidated, this is the discount that the liquidator can purchase it for
    uint8 liquidationfCashHaircut5BPS;
    // If an account has fCash that is being liquidated, this is the discount that the liquidator can purchase it for
    uint8 liquidationDebtBuffer5BPS;
    // Liquidity token haircut applied to cash claims, specified as a percentage between 0 and 100
    uint8[] liquidityTokenHaircuts;
    // Rate scalar used to determine the slippage of the market
    uint8[] rateScalars;
}

/// @dev Holds account level context information used to determine settlement and
/// free collateral actions. Total storage is 28 bytes
struct AccountContext {
    // Used to check when settlement must be triggered on an account
    uint40 nextSettleTime;
    // For lenders that never incur debt, we use this flag to skip the free collateral check.
    bytes1 hasDebt;
    // Length of the account's asset array
    uint8 assetArrayLength;
    // If this account has bitmaps set, this is the corresponding currency id
    uint16 bitmapCurrencyId;
    // 9 total active currencies possible (2 bytes each)
    bytes18 activeCurrencies;
}

/// @dev Holds nToken context information mapped via the nToken address, total storage is
/// 16 bytes
struct nTokenContext {
    // Currency id that the nToken represents
    uint16 currencyId;
    // Annual incentive emission rate denominated in WHOLE TOKENS (multiply by
    // INTERNAL_TOKEN_PRECISION to get the actual rate)
    uint32 incentiveAnnualEmissionRate;
    // The last block time at utc0 that the nToken was initialized at, zero if it
    // has never been initialized
    uint32 lastInitializedTime;
    // Length of the asset array, refers to the number of liquidity tokens an nToken
    // currently holds
    uint8 assetArrayLength;
    // Each byte is a specific nToken parameter
    bytes5 nTokenParameters;
    // Reserved bytes for future usage
    bytes15 _unused;
    // Set to true if a secondary rewarder is set
    bool hasSecondaryRewarder;
}

/// @dev Holds account balance information, total storage 32 bytes
struct BalanceStorage {
    // Number of nTokens held by the account
    uint80 nTokenBalance;
    // Last time the account claimed their nTokens
    uint32 lastClaimTime;
    // Incentives that the account no longer has a claim over
    uint56 accountIncentiveDebt;
    // Cash balance of the account
    int88 cashBalance;
}

/// @dev Holds information about a settlement rate, total storage 25 bytes
struct SettlementRateStorage {
    uint40 blockTime;
    uint128 settlementRate;
    uint8 underlyingDecimalPlaces;
}

/// @dev Holds information about a market, total storage is 42 bytes so this spans
/// two storage words
struct MarketStorage {
    // Total fCash in the market
    uint80 totalfCash;
    // Total asset cash in the market
    uint80 totalAssetCash;
    // Last annualized interest rate the market traded at
    uint32 lastImpliedRate;
    // Last recorded oracle rate for the market
    uint32 oracleRate;
    // Last time a trade was made
    uint32 previousTradeTime;
    // This is stored in slot + 1
    uint80 totalLiquidity;
}

struct ifCashStorage {
    // Notional amount of fCash at the slot, limited to int128 to allow for
    // future expansion
    int128 notional;
}

/// @dev A single portfolio asset in storage, total storage of 19 bytes
struct PortfolioAssetStorage {
    // Currency Id for the asset
    uint16 currencyId;
    // Maturity of the asset
    uint40 maturity;
    // Asset type (fCash or Liquidity Token marker)
    uint8 assetType;
    // Notional
    int88 notional;
}

/// @dev nToken total supply factors for the nToken, includes factors related
/// to claiming incentives, total storage 32 bytes. This is the deprecated version
struct nTokenTotalSupplyStorage_deprecated {
    // Total supply of the nToken
    uint96 totalSupply;
    // Integral of the total supply used for calculating the average total supply
    uint128 integralTotalSupply;
    // Last timestamp the supply value changed, used for calculating the integralTotalSupply
    uint32 lastSupplyChangeTime;
}

/// @dev nToken total supply factors for the nToken, includes factors related
/// to claiming incentives, total storage 32 bytes.
struct nTokenTotalSupplyStorage {
    // Total supply of the nToken
    uint96 totalSupply;
    // How many NOTE incentives should be issued per nToken in 1e18 precision
    uint128 accumulatedNOTEPerNToken;
    // Last timestamp when the accumulation happened
    uint32 lastAccumulatedTime;
}

/// @dev Used in view methods to return account balances in a developer friendly manner
struct AccountBalance {
    uint16 currencyId;
    int256 cashBalance;
    int256 nTokenBalance;
    uint256 lastClaimTime;
    uint256 accountIncentiveDebt;
}

struct VaultConfigStorage {
    // Vault Flags (documented in VaultConfiguration.sol)
    uint16 flags;
    // Primary currency the vault borrows in
    uint16 borrowCurrencyId;
    // Specified in whole tokens in 1e8 precision, allows a 4.2 billion min borrow size
    uint32 minAccountBorrowSize;
    // Minimum collateral ratio for a vault specified in basis points, valid values are greater than 10_000
    // where the largest minimum collateral ratio is 65_536 which is much higher than anything reasonable.
    uint16 minCollateralRatioBPS;
    // Allows up to a 12.75% annualized fee
    uint8 feeRate5BPS;
    // A percentage that represents the share of the cash raised that will go to the liquidator
    uint8 liquidationRate;
    // A percentage of the fee given to the protocol
    uint8 reserveFeeShare;
    // Maximum market index where a vault can borrow from
    uint8 maxBorrowMarketIndex;
    // Maximum collateral ratio that a liquidator can push a an account to during deleveraging
    uint16 maxDeleverageCollateralRatioBPS;
    // An optional list of secondary borrow currencies
    uint16[2] secondaryBorrowCurrencies;
    // 96 bytes left
}

struct VaultBorrowCapacityStorage {
    // Total fCash across all maturities that caps the borrow capacity
    uint80 maxBorrowCapacity;
    // Current usage of that total borrow capacity
    uint80 totalUsedBorrowCapacity;
}

struct VaultSecondaryBorrowStorage {
    // fCash borrowed for a specific maturity on a secondary currency
    uint80 totalfCashBorrowed;
    // Used for accounting how much secondary borrow a single account owes as the fCashBorrowed
    // increases or decreases
    uint80 totalAccountDebtShares;
}

struct VaultConfig {
    address vault;
    uint16 flags;
    uint16 borrowCurrencyId;
    int256 minAccountBorrowSize;
    int256 feeRate;
    int256 minCollateralRatio;
    int256 liquidationRate;
    int256 reserveFeeShare;
    uint256 maxBorrowMarketIndex;
    int256 maxDeleverageCollateralRatio;
    uint16[2] secondaryBorrowCurrencies;
    AssetRateParameters assetRate;
}

/// @notice Represents a Vault's current borrow and collateral state
struct VaultStateStorage {
    // This represents the total amount of borrowing in the vault for the current
    // vault term. This value must equal the total fCash borrowed by all accounts
    // in the vault.
    uint80 totalfCash;
    // The total amount of asset cash in the pool held as prepayment for fCash
    uint80 totalAssetCash;
    // Total vault shares in this maturity
    uint80 totalVaultShares;
    // Set to true if a vault has been fully settled and the cash can be pulled. Matured
    // accounts must wait for this flag to be set before they can proceed to exit after
    // maturity
    bool isSettled;
    // NOTE: 8 bits left
    // ----- This breaks into a new storage slot -------    
    // TODO: potentially make total strategy tokens bigger...
    // The total amount of strategy tokens held in the pool
    uint80 totalStrategyTokens;
    // Valuation of a strategy token at settlement
    int80 settlementStrategyTokenValue;
    // NOTE: 96 bits left
}

/// @notice Represents the remaining assets in a vault post settlement
struct VaultSettledAssetsStorage {
    // Remaining strategy tokens that have not been withdrawn
    uint80 remainingStrategyTokens;
    // Remaining asset cash that has not been withdrawn
    int80 remainingAssetCash;
}

struct VaultState {
    uint256 maturity;
    int256 totalfCash;
    bool isSettled;
    uint256 totalVaultShares;
    uint256 totalAssetCash;
    uint256 totalStrategyTokens;
    int256 settlementStrategyTokenValue;
}

/// @notice Represents an account's position within an individual vault
struct VaultAccountStorage {
    // The amount of fCash the account has borrowed from Notional. Stored as a uint but on the stack it
    // is represented as a negative number.
    uint80 fCash;
    // Vault shares that the account holds
    uint80 vaultShares;
    // Maturity when the vault shares and fCash will mature
    uint32 maturity;
}

struct VaultAccountSecondaryDebtShareStorage {
    // Maturity for the account's secondary borrows
    uint32 maturity;
    // Account debt shares for the first secondary currency
    uint80 accountDebtSharesOne;
    // Account debt shares for the second secondary currency
    uint80 accountDebtSharesTwo;
}

struct VaultAccount {
    int256 fCash;
    uint256 maturity;
    uint256 vaultShares;
    address account;
    // This cash balance is used just within a transaction to track deposits
    // and withdraws for an account. Must be zeroed by the time we store the account
    int256 tempCashBalance;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "./AggregatorInterface.sol";
import "./AggregatorV3Interface.sol";

interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface
{
}

// SPDX-License-Identifier: GPL-v3
pragma solidity >=0.7.0;

/// @notice Used as a wrapper for tokens that are interest bearing for an
/// underlying token. Follows the cToken interface, however, can be adapted
/// for other interest bearing tokens.
interface AssetRateAdapter {
    function token() external view returns (address);

    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function underlying() external view returns (address);

    function getExchangeRateStateful() external returns (int256);

    function getExchangeRateView() external view returns (int256);

    function getAnnualizedSupplyRate() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface AggregatorInterface {
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

interface INTokenAction {
    event nTokenApproveAll(address indexed owner, address indexed spender, uint256 amount);

    function nTokenTotalSupply(address nTokenAddress) external view returns (uint256);

    function nTokenTransferAllowance(
        uint16 currencyId,
        address owner,
        address spender
    ) external view returns (uint256);

    function nTokenBalanceOf(uint16 currencyId, address account) external view returns (uint256);

    function nTokenTransferApprove(
        uint16 currencyId,
        address owner,
        address spender,
        uint256 amount
    ) external returns (bool);

    function nTokenTransfer(
        uint16 currencyId,
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function nTokenTransferFrom(
        uint16 currencyId,
        address spender,
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function nTokenTransferApproveAll(address spender, uint256 amount) external returns (bool);

    function nTokenClaimIncentives() external returns (uint256);

    function nTokenPresentValueAssetDenominated(uint16 currencyId) external view returns (int256);

    function nTokenPresentValueUnderlyingDenominated(uint16 currencyId)
        external
        view
        returns (int256);

    function nTokenPresentValueUnderlyingExternal(uint16 currencyId)
        external
        view
        returns (uint256);

    function nTokenRedeemViaProxy(uint16 currencyId, uint256 shares, address receiver, address owner)
        external
        returns (uint256);

    function nTokenMintViaProxy(uint16 currencyId, uint256 assets, address receiver)
        external payable returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "../../contracts/global/Types.sol";

interface nERC1155Interface {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function supportsInterface(bytes4 interfaceId) external pure returns (bool);

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    function signedBalanceOf(address account, uint256 id) external view returns (int256);

    function signedBalanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (int256[] memory);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external payable;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external payable;

    function decodeToAssets(uint256[] calldata ids, uint256[] calldata amounts)
        external
        view
        returns (PortfolioAsset[] memory);

    function encodeToId(
        uint16 currencyId,
        uint40 maturity,
        uint8 assetType
    ) external pure returns (uint256 id);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "../../contracts/global/Types.sol";
import "../../interfaces/chainlink/AggregatorV2V3Interface.sol";
import "../../interfaces/notional/NotionalGovernance.sol";
import "../../interfaces/notional/IRewarder.sol";
import "../../interfaces/aave/ILendingPool.sol";

interface NotionalGovernance {
    event ListCurrency(uint16 newCurrencyId);
    event UpdateETHRate(uint16 currencyId);
    event UpdateAssetRate(uint16 currencyId);
    event UpdateCashGroup(uint16 currencyId);
    event DeployNToken(uint16 currencyId, address nTokenAddress);
    event UpdateDepositParameters(uint16 currencyId);
    event UpdateInitializationParameters(uint16 currencyId);
    event UpdateIncentiveEmissionRate(uint16 currencyId, uint32 newEmissionRate);
    event UpdateTokenCollateralParameters(uint16 currencyId);
    event UpdateGlobalTransferOperator(address operator, bool approved);
    event UpdateAuthorizedCallbackContract(address operator, bool approved);
    event UpdateMaxCollateralBalance(uint16 currencyId, uint72 maxCollateralBalance);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PauseRouterAndGuardianUpdated(address indexed pauseRouter, address indexed pauseGuardian);
    event UpdateSecondaryIncentiveRewarder(uint16 indexed currencyId, address rewarder);
    event UpdateLendingPool(address pool);

    function transferOwnership(address newOwner, bool direct) external;

    function claimOwnership() external;

    function upgradeNTokenBeacon(address newImplementation) external;

    function setPauseRouterAndGuardian(address pauseRouter_, address pauseGuardian_) external;

    function listCurrency(
        TokenStorage calldata assetToken,
        TokenStorage calldata underlyingToken,
        AggregatorV2V3Interface rateOracle,
        bool mustInvert,
        uint8 buffer,
        uint8 haircut,
        uint8 liquidationDiscount
    ) external returns (uint16 currencyId);

    function updateMaxCollateralBalance(
        uint16 currencyId,
        uint72 maxCollateralBalanceInternalPrecision
    ) external;

    function enableCashGroup(
        uint16 currencyId,
        AssetRateAdapter assetRateOracle,
        CashGroupSettings calldata cashGroup,
        string calldata underlyingName,
        string calldata underlyingSymbol
    ) external;

    function updateDepositParameters(
        uint16 currencyId,
        uint32[] calldata depositShares,
        uint32[] calldata leverageThresholds
    ) external;

    function updateInitializationParameters(
        uint16 currencyId,
        uint32[] calldata annualizedAnchorRates,
        uint32[] calldata proportions
    ) external;

    function updateIncentiveEmissionRate(uint16 currencyId, uint32 newEmissionRate) external;

    function updateTokenCollateralParameters(
        uint16 currencyId,
        uint8 residualPurchaseIncentive10BPS,
        uint8 pvHaircutPercentage,
        uint8 residualPurchaseTimeBufferHours,
        uint8 cashWithholdingBuffer10BPS,
        uint8 liquidationHaircutPercentage
    ) external;

    function updateCashGroup(uint16 currencyId, CashGroupSettings calldata cashGroup) external;

    function updateAssetRate(uint16 currencyId, AssetRateAdapter rateOracle) external;

    function updateETHRate(
        uint16 currencyId,
        AggregatorV2V3Interface rateOracle,
        bool mustInvert,
        uint8 buffer,
        uint8 haircut,
        uint8 liquidationDiscount
    ) external;

    function updateGlobalTransferOperator(address operator, bool approved) external;

    function updateAuthorizedCallbackContract(address operator, bool approved) external;

    function setLendingPool(ILendingPool pool) external;

    function setSecondaryIncentiveRewarder(uint16 currencyId, IRewarder rewarder) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "../../contracts/global/Types.sol";

interface NotionalCalculations {
    function calculateNTokensToMint(uint16 currencyId, uint88 amountToDepositExternalPrecision)
        external
        view
        returns (uint256);

    function getfCashAmountGivenCashAmount(
        uint16 currencyId,
        int88 netCashToAccount,
        uint256 marketIndex,
        uint256 blockTime
    ) external view returns (int256);

    function getCashAmountGivenfCashAmount(
        uint16 currencyId,
        int88 fCashAmount,
        uint256 marketIndex,
        uint256 blockTime
    ) external view returns (int256, int256);

    function nTokenGetClaimableIncentives(address account, uint256 blockTime)
        external
        view
        returns (uint256);

    function getPresentfCashValue(
        uint16 currencyId,
        uint256 maturity,
        int256 notional,
        uint256 blockTime,
        bool riskAdjusted
    ) external view returns (int256 presentValue);

    function getMarketIndex(
        uint256 maturity,
        uint256 blockTime
    ) external pure returns (uint8 marketIndex);

    function getfCashLendFromDeposit(
        uint16 currencyId,
        uint256 depositAmountExternal,
        uint256 maturity,
        uint32 minLendRate,
        uint256 blockTime,
        bool useUnderlying
    ) external view returns (
        uint88 fCashAmount,
        uint8 marketIndex,
        bytes32 encodedTrade
    );

    function getfCashBorrowFromPrincipal(
        uint16 currencyId,
        uint256 borrowedAmountExternal,
        uint256 maturity,
        uint32 maxBorrowRate,
        uint256 blockTime,
        bool useUnderlying
    ) external view returns (
        uint88 fCashDebt,
        uint8 marketIndex,
        bytes32 encodedTrade
    );

    function getDepositFromfCashLend(
        uint16 currencyId,
        uint256 fCashAmount,
        uint256 maturity,
        uint32 minLendRate,
        uint256 blockTime
    ) external view returns (
        uint256 depositAmountUnderlying,
        uint256 depositAmountAsset,
        uint8 marketIndex,
        bytes32 encodedTrade
    );

    function getPrincipalFromfCashBorrow(
        uint16 currencyId,
        uint256 fCashBorrow,
        uint256 maturity,
        uint32 maxBorrowRate,
        uint256 blockTime
    ) external view returns (
        uint256 borrowAmountUnderlying,
        uint256 borrowAmountAsset,
        uint8 marketIndex,
        bytes32 encodedTrade
    );

    function convertCashBalanceToExternal(
        uint16 currencyId,
        int256 cashBalanceInternal,
        bool useUnderlying
    ) external view returns (int256);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "../../contracts/global/Types.sol";

interface NotionalViews {
    function getMaxCurrencyId() external view returns (uint16);

    function getCurrencyId(address tokenAddress) external view returns (uint16 currencyId);

    function getCurrency(uint16 currencyId)
        external
        view
        returns (Token memory assetToken, Token memory underlyingToken);

    function getRateStorage(uint16 currencyId)
        external
        view
        returns (ETHRateStorage memory ethRate, AssetRateStorage memory assetRate);

    function getCurrencyAndRates(uint16 currencyId)
        external
        view
        returns (
            Token memory assetToken,
            Token memory underlyingToken,
            ETHRate memory ethRate,
            AssetRateParameters memory assetRate
        );

    function getCashGroup(uint16 currencyId) external view returns (CashGroupSettings memory);

    function getCashGroupAndAssetRate(uint16 currencyId)
        external
        view
        returns (CashGroupSettings memory cashGroup, AssetRateParameters memory assetRate);

    function getInitializationParameters(uint16 currencyId)
        external
        view
        returns (int256[] memory annualizedAnchorRates, int256[] memory proportions);

    function getDepositParameters(uint16 currencyId)
        external
        view
        returns (int256[] memory depositShares, int256[] memory leverageThresholds);

    function nTokenAddress(uint16 currencyId) external view returns (address);

    function getNoteToken() external view returns (address);

    function getOwnershipStatus() external view returns (address owner, address pendingOwner);

    function getGlobalTransferOperatorStatus(address operator)
        external
        view
        returns (bool isAuthorized);

    function getAuthorizedCallbackContractStatus(address callback)
        external
        view
        returns (bool isAuthorized);

    function getSecondaryIncentiveRewarder(uint16 currencyId)
        external
        view
        returns (address incentiveRewarder);

    function getSettlementRate(uint16 currencyId, uint40 maturity)
        external
        view
        returns (AssetRateParameters memory);

    function getMarket(
        uint16 currencyId,
        uint256 maturity,
        uint256 settlementDate
    ) external view returns (MarketParameters memory);

    function getActiveMarkets(uint16 currencyId) external view returns (MarketParameters[] memory);

    function getActiveMarketsAtBlockTime(uint16 currencyId, uint32 blockTime)
        external
        view
        returns (MarketParameters[] memory);

    function getReserveBalance(uint16 currencyId) external view returns (int256 reserveBalance);

    function getNTokenPortfolio(address tokenAddress)
        external
        view
        returns (PortfolioAsset[] memory liquidityTokens, PortfolioAsset[] memory netfCashAssets);

    function getNTokenAccount(address tokenAddress)
        external
        view
        returns (
            uint16 currencyId,
            uint256 totalSupply,
            uint256 incentiveAnnualEmissionRate,
            uint256 lastInitializedTime,
            bytes5 nTokenParameters,
            int256 cashBalance,
            uint256 accumulatedNOTEPerNToken,
            uint256 lastAccumulatedTime
        );

    function getAccount(address account)
        external
        view
        returns (
            AccountContext memory accountContext,
            AccountBalance[] memory accountBalances,
            PortfolioAsset[] memory portfolio
        );

    function getAccountContext(address account) external view returns (AccountContext memory);

    function getAccountBalance(uint16 currencyId, address account)
        external
        view
        returns (
            int256 cashBalance,
            int256 nTokenBalance,
            uint256 lastClaimTime
        );

    function getAccountPortfolio(address account) external view returns (PortfolioAsset[] memory);

    function getfCashNotional(
        address account,
        uint16 currencyId,
        uint256 maturity
    ) external view returns (int256);

    function getAssetsBitmap(address account, uint16 currencyId) external view returns (bytes32);

    function getFreeCollateral(address account) external view returns (int256, int256[] memory);

    function getTreasuryManager() external view returns (address);

    function getReserveBuffer(uint16 currencyId) external view returns (uint256);

    function getLendingPool() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

interface NotionalTreasury {

    /// @notice Emitted when reserve balance is updated
    event ReserveBalanceUpdated(uint16 indexed currencyId, int256 newBalance);
    /// @notice Emitted when reserve balance is harvested
    event ExcessReserveBalanceHarvested(uint16 indexed currencyId, int256 harvestAmount);
    /// @dev Emitted when treasury manager is updated
    event TreasuryManagerChanged(address indexed previousManager, address indexed newManager);
    /// @dev Emitted when reserve buffer value is updated
    event ReserveBufferUpdated(uint16 currencyId, uint256 bufferAmount);

    function claimCOMPAndTransfer(address[] calldata ctokens) external returns (uint256);

    function transferReserveToTreasury(uint16[] calldata currencies)
        external
        returns (uint256[] memory);

    function setTreasuryManager(address manager) external;

    function setReserveBuffer(uint16 currencyId, uint256 amount) external;

    function setReserveCashBalance(uint16 currencyId, int256 reserveBalance) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

interface IRewarder {
    function claimRewards(
        address account,
        uint16 currencyId,
        uint256 nTokenBalanceBefore,
        uint256 nTokenBalanceAfter,
        int256  netNTokenSupplyChange,
        uint256 NOTETokensClaimed
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

struct LendingPoolStorage {
  ILendingPool lendingPool;
}

interface ILendingPool {

  /**
   * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to deposit
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   **/
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

    /**
   * @dev Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state of the reserve
   **/
  function getReserveData(address asset) external view returns (ReserveData memory);

  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
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
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
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

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.15;

library BalancerConstants {
    uint256 internal constant BALANCER_PRECISION = 1e18;
    uint256 internal constant BALANCER_PRECISION_SQUARED = 1e36;
    uint256 internal constant BALANCER_ORACLE_WEIGHT_PRECISION = 1e8;
    uint32 internal constant SLIPPAGE_LIMIT_PRECISION = 1e8;

    /// @notice Precision for all percentages used by the vault
    /// 1e4 = 100% (i.e. maxBalancerPoolShare)
    uint16 internal constant VAULT_PERCENT_BASIS = 1e4;
    /// @notice Buffer percentage between the desired share of the Balancer pool
    /// and the maximum share of the pool allowed by maxBalancerPoolShare 1e4 = 100%, 8e3 = 80%
    uint16 internal constant BALANCER_POOL_SHARE_BUFFER = 8e3;
    /// @notice Max settlement cool down period allowed (1 day)
    uint16 internal constant MAX_SETTLEMENT_COOLDOWN_IN_MINUTES = 24 * 60;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

library Errors {
    error InvalidPrice(uint256 oraclePrice, uint256 poolPrice);
    error NotInSettlementWindow();
    error InvalidEmergencySettlement();
    error HasNotMatured();
    error PostMaturitySettlement();
    error RedeemingTooMuch(
        int256 underlyingRedeemed,
        int256 underlyingCashRequiredToSettle
    );
    error SlippageTooHigh(uint32 slippage, uint32 limit);
    error InSettlementCoolDown(uint32 lastSettlementTimestamp, uint32 coolDownInMinutes);
    /// @notice settleVault called when there is no debt
    error SettlementNotRequired();
    error InvalidRewardToken(address token);
    error InvalidJoinAmounts(uint256 oraclePrice, uint256 maxPrimary, uint256 maxSecondary);
    error BalancerPoolShareTooHigh(uint256 totalBPTHeld, uint256 bptThreshold);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

library TypeConvert {

    function toUint(int256 x) internal pure returns (uint256) {
        require(x >= 0);
        return uint256(x);
    }

    function toInt(uint256 x) internal pure returns (int256) {
        require (x <= uint256(type(int256).max)); // dev: toInt overflow
        return int256(x);
    }

    function toInt80(int256 x) internal pure returns (int80) {
        require (int256(type(int80).min) <= x && x <= int256(type(int80).max)); // dev: toInt overflow
        return int80(x);
    }

    function toUint80(uint256 x) internal pure returns (uint80) {
        require (x <= uint256(type(uint80).max));
        return uint80(x);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Math} from "./Math.sol";
import {FixedPoint} from "./FixedPoint.sol";

library StableMath {
    using FixedPoint for uint256;
    
    uint256 internal constant _AMP_PRECISION = 1e3;

    error CalculationDidNotConverge();

    // Note on unchecked arithmetic:
    // This contract performs a large number of additions, subtractions, multiplications and divisions, often inside
    // loops. Since many of these operations are gas-sensitive (as they happen e.g. during a swap), it is important to
    // not make any unnecessary checks. We rely on a set of invariants to avoid having to use checked arithmetic (the
    // Math library), including:
    //  - the number of tokens is bounded by _MAX_STABLE_TOKENS
    //  - the amplification parameter is bounded by _MAX_AMP * _AMP_PRECISION, which fits in 23 bits
    //  - the token balances are bounded by 2^112 (guaranteed by the Vault) times 1e18 (the maximum scaling factor),
    //    which fits in 172 bits
    //
    // This means e.g. we can safely multiply a balance by the amplification parameter without worrying about overflow.

    // Computes the invariant given the current balances, using the Newton-Raphson approximation.
    // The amplification parameter equals: A n^(n-1)
    function _calculateInvariant(
        uint256 amplificationParameter,
        uint256[] memory balances,
        bool roundUp
    ) internal pure returns (uint256) {
        /**********************************************************************************************
        // invariant                                                                                 //
        // D = invariant                                                  D^(n+1)                    //
        // A = amplification coefficient      A  n^n S + D = A D n^n + -----------                   //
        // S = sum of balances                                             n^n P                     //
        // P = product of balances                                                                   //
        // n = number of tokens                                                                      //
        *********x************************************************************************************/

        unchecked {
            // We support rounding up or down.
            uint256 sum = 0;
            uint256 numTokens = balances.length;
            for (uint256 i = 0; i < numTokens; i++) {
                sum = sum.add(balances[i]);
            }
            if (sum == 0) {
                return 0;
            }

            uint256 prevInvariant = 0;
            uint256 invariant = sum;
            uint256 ampTimesTotal = amplificationParameter * numTokens;

            for (uint256 i = 0; i < 255; i++) {
                uint256 P_D = balances[0] * numTokens;
                for (uint256 j = 1; j < numTokens; j++) {
                    P_D = Math.div(Math.mul(Math.mul(P_D, balances[j]), numTokens), invariant, roundUp);
                }
                prevInvariant = invariant;
                invariant = Math.div(
                    Math.mul(Math.mul(numTokens, invariant), invariant).add(
                        Math.div(Math.mul(Math.mul(ampTimesTotal, sum), P_D), _AMP_PRECISION, roundUp)
                    ),
                    Math.mul(numTokens + 1, invariant).add(
                        // No need to use checked arithmetic for the amp precision, the amp is guaranteed to be at least 1
                        Math.div(Math.mul(ampTimesTotal - _AMP_PRECISION, P_D), _AMP_PRECISION, !roundUp)
                    ),
                    roundUp
                );

                if (invariant > prevInvariant) {
                    if (invariant - prevInvariant <= 1) {
                        return invariant;
                    }
                } else if (prevInvariant - invariant <= 1) {
                    return invariant;
                }
            }
        }

        revert CalculationDidNotConverge();
    }

    /**
     * @dev Calculates the spot price of token Y in token X.
     */
    function _calcSpotPrice(
        uint256 amplificationParameter,
        uint256 invariant, 
        uint256 balanceX,
        uint256 balanceY
    ) internal pure returns (uint256) {
        /**************************************************************************************************************
        //                                                                                                           //
        //                             2.a.x.y + a.y^2 + b.y                                                         //
        // spot price Y/X = - dx/dy = -----------------------                                                        //
        //                             2.a.x.y + a.x^2 + b.x                                                         //
        //                                                                                                           //
        // n = 2                                                                                                     //
        // a = amp param * n                                                                                         //
        // b = D + a.(S - D)                                                                                         //
        // D = invariant                                                                                             //
        // S = sum of balances but x,y = 0 since x  and y are the only tokens                                        //
        **************************************************************************************************************/

        unchecked {
            uint256 a = (amplificationParameter * 2) / _AMP_PRECISION;
            uint256 b = Math.mul(invariant, a).sub(invariant);

            uint256 axy2 = Math.mul(a * 2, balanceX).mulDown(balanceY); // n = 2

            // dx = a.x.y.2 + a.y^2 - b.y
            uint256 derivativeX = axy2.add(Math.mul(a, balanceY).mulDown(balanceY)).sub(b.mulDown(balanceY));

            // dy = a.x.y.2 + a.x^2 - b.x
            uint256 derivativeY = axy2.add(Math.mul(a, balanceX).mulDown(balanceX)).sub(b.mulDown(balanceX));

            // The rounding direction is irrelevant as we're about to introduce a much larger error when converting to log
            // space. We use `divUp` as it prevents the result from being zero, which would make the logarithm revert. A
            // result of zero is therefore only possible with zero balances, which are prevented via other means.
            return derivativeX.divUp(derivativeY);
        }
    }

    function _balances(uint256 balanceX, uint256 balanceY) internal pure returns (uint256[] memory balances) {
        balances = new uint256[](2);
        balances[0] = balanceX;
        balances[1] = balanceY;
    }

    // This function calculates the balance of a given token (tokenIndex)
    // given all the other balances and the invariant
    function _getTokenBalanceGivenInvariantAndAllOtherBalances(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 invariant,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        // Rounds result up overall
        unchecked {
            uint256 ampTimesTotal = amplificationParameter * balances.length;
            uint256 sum = balances[0];
            uint256 P_D = balances[0] * balances.length;
            for (uint256 j = 1; j < balances.length; j++) {
                P_D = Math.divDown(Math.mul(Math.mul(P_D, balances[j]), balances.length), invariant);
                sum = sum.add(balances[j]);
            }
            // No need to use safe math, based on the loop above `sum` is greater than or equal to `balances[tokenIndex]`
            sum = sum - balances[tokenIndex];

            uint256 inv2 = Math.mul(invariant, invariant);
            // We remove the balance fromm c by multiplying it
            uint256 c = Math.mul(
                Math.mul(Math.divUp(inv2, Math.mul(ampTimesTotal, P_D)), _AMP_PRECISION),
                balances[tokenIndex]
            );
            uint256 b = sum.add(Math.mul(Math.divDown(invariant, ampTimesTotal), _AMP_PRECISION));

            // We iterate to find the balance
            uint256 prevTokenBalance = 0;
            // We multiply the first iteration outside the loop with the invariant to set the value of the
            // initial approximation.
            uint256 tokenBalance = Math.divUp(inv2.add(c), invariant.add(b));

            for (uint256 i = 0; i < 255; i++) {
                prevTokenBalance = tokenBalance;

                tokenBalance = Math.divUp(
                    Math.mul(tokenBalance, tokenBalance).add(c),
                    Math.mul(tokenBalance, 2).add(b).sub(invariant)
                );

                if (tokenBalance > prevTokenBalance) {
                    if (tokenBalance - prevTokenBalance <= 1) {
                        return tokenBalance;
                    }
                } else if (prevTokenBalance - tokenBalance <= 1) {
                    return tokenBalance;
                }
            }
        }

        revert CalculationDidNotConverge();
    }

    function _calcTokenOutGivenExactBptIn(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage,
        uint256 currentInvariant
    ) internal pure returns (uint256) {
        // Token out, so we round down overall.

        unchecked {
            uint256 newInvariant = bptTotalSupply.sub(bptAmountIn).divUp(bptTotalSupply).mulUp(currentInvariant);

            // Calculate amount out without fee
            uint256 newBalanceTokenIndex = _getTokenBalanceGivenInvariantAndAllOtherBalances(
                amp,
                balances,
                newInvariant,
                tokenIndex
            );
            uint256 amountOutWithoutFee = balances[tokenIndex].sub(newBalanceTokenIndex);

            // First calculate the sum of all token balances, which will be used to calculate
            // the current weight of each token
            uint256 sumBalances = 0;
            for (uint256 i = 0; i < balances.length; i++) {
                sumBalances = sumBalances.add(balances[i]);
            }

            // We can now compute how much excess balance is being withdrawn as a result of the virtual swaps, which result
            // in swap fees.
            uint256 currentWeight = balances[tokenIndex].divDown(sumBalances);
            uint256 taxablePercentage = currentWeight.complement();

            // Swap fees are typically charged on 'token in', but there is no 'token in' here, so we apply it
            // to 'token out'. This results in slightly larger price impact. Fees are rounded up.
            uint256 taxableAmount = amountOutWithoutFee.mulUp(taxablePercentage);
            uint256 nonTaxableAmount = amountOutWithoutFee.sub(taxableAmount);

            // No need to use checked arithmetic for the swap fee, it is guaranteed to be lower than 50%
            return nonTaxableAmount.add(taxableAmount.mulDown(FixedPoint.ONE - swapFeePercentage));
        }
    }

    // Computes how many tokens can be taken out of a pool if `tokenAmountIn` are sent, given the current balances.
    // The amplification parameter equals: A n^(n-1)
    function _calcOutGivenIn(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountIn,
        uint256 invariant
    ) internal pure returns (uint256) {
        /**************************************************************************************************************
        // outGivenIn token x for y - polynomial equation to solve                                                   //
        // ay = amount out to calculate                                                                              //
        // by = balance token out                                                                                    //
        // y = by - ay (finalBalanceOut)                                                                             //
        // D = invariant                                               D                     D^(n+1)                 //
        // A = amplification coefficient               y^2 + ( S - ----------  - D) * y -  ------------- = 0         //
        // n = number of tokens                                    (A * n^n)               A * n^2n * P              //
        // S = sum of final balances but y                                                                           //
        // P = product of final balances but y                                                                       //
        **************************************************************************************************************/

        // Amount out, so we round down overall.
        unchecked {
            balances[tokenIndexIn] = balances[tokenIndexIn].add(tokenAmountIn);

            uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(
                amplificationParameter,
                balances,
                invariant,
                tokenIndexOut
            );

            // No need to use checked arithmetic since `tokenAmountIn` was actually added to the same balance right before
            // calling `_getTokenBalanceGivenInvariantAndAllOtherBalances` which doesn't alter the balances array.
            balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;

            return balances[tokenIndexOut].sub(finalBalanceOut).sub(1);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow checks.
 * Adapted from OpenZeppelin's SafeMath library
 */
library Math {
    /**
     * @dev Returns the addition of two unsigned integers of 256 bits, reverting on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers of 256 bits, reverting on overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        return a - b;
    }

    /**
     * @dev Returns the largest of two numbers of 256 bits.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers of 256 bits.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(
        uint256 a,
        uint256 b,
        bool roundUp
    ) internal pure returns (uint256) {
        return roundUp ? divUp(a, b) : divDown(a, b);
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        } else {
            return 1 + (a - 1) / b;
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.15;

/* solhint-disable private-vars-leading-underscore */

library FixedPoint {
    uint256 internal constant ONE = 1e18; // 18 decimal places
    uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; // 10^(-14)

    // Minimum base for the power function when the exponent is 'free' (larger than ONE).
    uint256 internal constant MIN_POW_BASE_FREE_EXPONENT = 0.7e18;

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        // Fixed Point addition is the same as regular checked addition

        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        // Fixed Point addition is the same as regular checked addition

        return a - b;
    }

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        return product / ONE;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;

        if (product == 0) {
            return 0;
        } else {
            // The traditional divUp formula is:
            // divUp(x, y) := (x + y - 1) / y
            // To avoid intermediate overflow in the addition, we distribute the division and get:
            // divUp(x, y) := (x - 1) / y + 1
            // Note that this requires x != 0, which we already tested for.

            return ((product - 1) / ONE) + 1;
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            return aInflated / b;
        }
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;

            // The traditional divUp formula is:
            // divUp(x, y) := (x + y - 1) / y
            // To avoid intermediate overflow in the addition, we distribute the division and get:
            // divUp(x, y) := (x - 1) / y + 1
            // Note that this requires x != 0, which we already tested for.

            return ((aInflated - 1) / b) + 1;
        }
    }

    /**
     * @dev Returns the complement of a value (1 - x), capped to 0 if x is larger than 1.
     *
     * Useful when computing the complement for values with some level of relative error, as it strips this error and
     * prevents intermediate negative values.
     */
    function complement(uint256 x) internal pure returns (uint256) {
        return (x < ONE) ? (ONE - x) : 0;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

/// @title All shared constants for the Notional system should be declared here.
library Constants {
    uint8 internal constant CETH_DECIMAL_PLACES = 8;

    // Token precision used for all internal balances, TokenHandler library ensures that we
    // limit the dust amount caused by precision mismatches
    int256 internal constant INTERNAL_TOKEN_PRECISION = 1e8;
    uint256 internal constant INCENTIVE_ACCUMULATION_PRECISION = 1e18;

    // ETH will be initialized as the first currency
    address internal constant ETH_ADDRESS = address(0);
    uint256 internal constant ETH_CURRENCY_ID = 1;
    uint8 internal constant ETH_DECIMAL_PLACES = 18;
    int256 internal constant ETH_DECIMALS = 1e18;
    // Used to prevent overflow when converting decimal places to decimal precision values via
    // 10**decimalPlaces. This is a safe value for int256 and uint256 variables. We apply this
    // constraint when storing decimal places in governance.
    uint256 internal constant MAX_DECIMAL_PLACES = 36;

    // Address of the reserve account
    address internal constant RESERVE = address(0);

    // Most significant bit
    bytes32 internal constant MSB = 0x8000000000000000000000000000000000000000000000000000000000000000;

    // Each bit set in this mask marks where an active market should be in the bitmap
    // if the first bit refers to the reference time. Used to detect idiosyncratic
    // fcash in the nToken accounts
    bytes32 internal constant ACTIVE_MARKETS_MASK = (
        MSB >> ( 90 - 1) | // 3 month
        MSB >> (105 - 1) | // 6 month
        MSB >> (135 - 1) | // 1 year
        MSB >> (147 - 1) | // 2 year
        MSB >> (183 - 1) | // 5 year
        MSB >> (211 - 1) | // 10 year
        MSB >> (251 - 1)   // 20 year
    );

    // Basis for percentages
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    // Max number of traded markets, also used as the maximum number of assets in a portfolio array
    uint256 internal constant MAX_TRADED_MARKET_INDEX = 7;
    // Max number of fCash assets in a bitmap, this is based on the gas costs of calculating free collateral
    // for a bitmap portfolio
    uint256 internal constant MAX_BITMAP_ASSETS = 20;
    uint256 internal constant FIVE_MINUTES = 300;

    // Internal date representations, note we use a 6/30/360 week/month/year convention here
    uint256 internal constant DAY = 86400;
    // We use six day weeks to ensure that all time references divide evenly
    uint256 internal constant WEEK = DAY * 6;
    uint256 internal constant MONTH = WEEK * 5;
    uint256 internal constant QUARTER = MONTH * 3;
    uint256 internal constant YEAR = QUARTER * 4;

    // These constants are used in DateTime.sol
    uint256 internal constant DAYS_IN_WEEK = 6;
    uint256 internal constant DAYS_IN_MONTH = 30;
    uint256 internal constant DAYS_IN_QUARTER = 90;

    // Offsets for each time chunk denominated in days
    uint256 internal constant MAX_DAY_OFFSET = 90;
    uint256 internal constant MAX_WEEK_OFFSET = 360;
    uint256 internal constant MAX_MONTH_OFFSET = 2160;
    uint256 internal constant MAX_QUARTER_OFFSET = 7650;

    // Offsets for each time chunk denominated in bits
    uint256 internal constant WEEK_BIT_OFFSET = 90;
    uint256 internal constant MONTH_BIT_OFFSET = 135;
    uint256 internal constant QUARTER_BIT_OFFSET = 195;

    // This is a constant that represents the time period that all rates are normalized by, 360 days
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;
    // Number of decimal places that rates are stored in, equals 100%
    int256 internal constant RATE_PRECISION = 1e9;
    // One basis point in RATE_PRECISION terms
    uint256 internal constant BASIS_POINT = uint256(RATE_PRECISION / 10000);
    // Used to when calculating the amount to deleverage of a market when minting nTokens
    uint256 internal constant DELEVERAGE_BUFFER = 300 * BASIS_POINT;
    // Used for scaling cash group factors
    uint256 internal constant FIVE_BASIS_POINTS = 5 * BASIS_POINT;
    // Used for residual purchase incentive and cash withholding buffer
    uint256 internal constant TEN_BASIS_POINTS = 10 * BASIS_POINT;

    // This is the ABDK64x64 representation of RATE_PRECISION
    // RATE_PRECISION_64x64 = ABDKMath64x64.fromUint(RATE_PRECISION)
    int128 internal constant RATE_PRECISION_64x64 = 0x3b9aca000000000000000000;
    int128 internal constant LOG_RATE_PRECISION_64x64 = 382276781265598821176;
    // Limit the market proportion so that borrowing cannot hit extremely high interest rates
    int256 internal constant MAX_MARKET_PROPORTION = RATE_PRECISION * 99 / 100;

    uint8 internal constant FCASH_ASSET_TYPE = 1;
    // Liquidity token asset types are 1 + marketIndex (where marketIndex is 1-indexed)
    uint8 internal constant MIN_LIQUIDITY_TOKEN_INDEX = 2;
    uint8 internal constant MAX_LIQUIDITY_TOKEN_INDEX = 8;

    // Used for converting bool to bytes1, solidity does not have a native conversion
    // method for this
    bytes1 internal constant BOOL_FALSE = 0x00;
    bytes1 internal constant BOOL_TRUE = 0x01;

    // Account context flags
    bytes1 internal constant HAS_ASSET_DEBT = 0x01;
    bytes1 internal constant HAS_CASH_DEBT = 0x02;
    bytes2 internal constant ACTIVE_IN_PORTFOLIO = 0x8000;
    bytes2 internal constant ACTIVE_IN_BALANCES = 0x4000;
    bytes2 internal constant UNMASK_FLAGS = 0x3FFF;
    uint16 internal constant MAX_CURRENCIES = uint16(UNMASK_FLAGS);

    // Equal to 100% of all deposit amounts for nToken liquidity across fCash markets.
    int256 internal constant DEPOSIT_PERCENT_BASIS = 1e8;
    uint256 internal constant SLIPPAGE_LIMIT_PRECISION = 1e8;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

import {NotionalProxy} from "../../interfaces/notional/NotionalProxy.sol";
import {IWstETH} from "../../interfaces/IWstETH.sol";
import {IBalancerVault, IAsset} from "../../interfaces/balancer/IBalancerVault.sol";
import {WETH9} from "../../interfaces/WETH9.sol";
import {ISwapRouter as UniV3ISwapRouter} from "../../interfaces/uniswap/v3/ISwapRouter.sol";
import {IUniV2Router2} from "../../interfaces/uniswap/v2/IUniV2Router2.sol";
import {ICurveRouter} from "../../interfaces/curve/ICurveRouter.sol";
import {ICurveRegistry} from "../../interfaces/curve/ICurveRegistry.sol";

/// @title Hardcoded Deployment Addresses for ETH Mainnet
library Deployments {
    NotionalProxy internal constant NOTIONAL = NotionalProxy(0xD8229B55bD73c61D840d339491219ec6Fa667B0a);
    IWstETH internal constant WRAPPED_STETH = IWstETH(0xd2D24271030ecE6068C7E8874daF61fCC3225acB);
    address internal constant ETH_ADDRESS = address(0);
    WETH9 internal constant WETH =
        WETH9(0xdFCeA9088c8A88A76FF74892C1457C17dfeef9C1);
    IBalancerVault internal constant BALANCER_VAULT =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    UniV3ISwapRouter internal constant UNIV3_ROUTER = UniV3ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address internal constant ZERO_EX = address(0);
    IUniV2Router2 internal constant UNIV2_ROUTER = IUniV2Router2(address(0));

    address internal constant ALT_ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ICurveRegistry public constant CURVE_REGISTRY = ICurveRegistry(address(0));
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(address(0));
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import {IERC20} from "./IERC20.sol";

interface IWstETH is IERC20 {
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
    function stEthPerToken() external view returns (uint256);
    function stETH() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface WETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.15;

interface ICurveRouter {
    function exchange(
        uint256 _amount,
        address[6] calldata _route,
        uint256[8] calldata _indices,
        uint256 _min_received
    ) external payable;

    function get_exchange_routing(
        address _initial,
        address _target,
        uint256 _amount
    ) external view returns (
        address[6] memory route,
        uint256[8] memory indexes,
        uint256 expectedOutputAmount
    );

    function can_route(address _initial, address _target) external view returns (bool);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.15;

interface ICurveRegistry {
    function find_pool_for_coins(address _from, address _to)
        external
        view
        returns (address);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.15;
pragma abicoder v2;

import './IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.15;
pragma abicoder v2;

interface IUniV2Router2 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.15;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC20} from "../../interfaces/IERC20.sol";
import {IEIP20NonStandard} from "../../interfaces/IEIP20NonStandard.sol";
import {Deployments} from "../global/Deployments.sol";

library TokenUtils {
    error ERC20Error();

    function tokenBalance(address token) internal view returns (uint256) {
        return
            token == Deployments.ETH_ADDRESS
                ? address(this).balance
                : IERC20(token).balanceOf(address(this));
    }

    function checkApprove(IERC20 token, address spender, uint256 amount) internal {
        if (address(token) == address(0)) return;

        IEIP20NonStandard(address(token)).approve(spender, amount);
        _checkReturnCode();
    }

    function checkRevoke(IERC20 token, address spender) internal {
        if (address(token) == address(0)) return;

        IEIP20NonStandard(address(token)).approve(spender, 0);
        _checkReturnCode();
    }

    function checkTransfer(IERC20 token, address receiver, uint256 amount) internal {
        IEIP20NonStandard(address(token)).transfer(receiver, amount);
        _checkReturnCode();
    }

    // Supports checking return codes on non-standard ERC20 contracts
    function _checkReturnCode() private pure {
        bool success;
        uint256[1] memory result;
        assembly {
            switch returndatasize()
                case 0 {
                    // This is a non-standard ERC-20
                    success := 1 // set success to true
                }
                case 32 {
                    // This is a compliant ERC-20
                    returndatacopy(result, 0, 32)
                    success := mload(result) // Set `success = returndata` of external call
                }
                default {
                    // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }

        if (!success) revert ERC20Error();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ITradingModule, Trade} from "../../interfaces/trading/ITradingModule.sol";
import {nProxy} from "../proxy/nProxy.sol";

/// @notice TradeHandler is an internal library to be compiled into StrategyVaults to interact
/// with the TradeModule and execute trades
library TradeHandler {

    /// @notice Can be used to delegate call to the TradingModule's implementation in order to execute
    /// a trade.
    function _executeTradeWithDynamicSlippage(
        Trade memory trade,
        uint16 dexId,
        ITradingModule tradingModule,
        uint32 dynamicSlippageLimit
    ) internal returns (uint256 amountSold, uint256 amountBought) {
        (bool success, bytes memory result) = nProxy(payable(address(tradingModule))).getImplementation()
            .delegatecall(abi.encodeWithSelector(
                ITradingModule.executeTradeWithDynamicSlippage.selector,
                dexId, trade, dynamicSlippageLimit
            )
        );
        require(success);
        (amountSold, amountBought) = abi.decode(result, (uint256, uint256));
    }

    /// @notice Can be used to delegate call to the TradingModule's implementation in order to execute
    /// a trade.
    function _executeTrade(
        Trade memory trade,
        uint16 dexId,
        ITradingModule tradingModule
    ) internal returns (uint256 amountSold, uint256 amountBought) {
        (bool success, bytes memory result) = nProxy(payable(address(tradingModule))).getImplementation()
            .delegatecall(abi.encodeWithSelector(ITradingModule.executeTrade.selector, dexId, trade));
        require(success);
        (amountSold, amountBought) = abi.decode(result, (uint256, uint256));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {IBalancerVault, IAsset} from "../../../../../interfaces/balancer/IBalancerVault.sol";
import {PoolContext, PoolParams} from "../../BalancerVaultTypes.sol";
import {IPriceOracle} from "../../../../../interfaces/balancer/IPriceOracle.sol";
import {Constants} from "../../../../global/Constants.sol";
import {Deployments} from "../../../../global/Deployments.sol";
import {BalancerConstants} from "../BalancerConstants.sol";
import {TokenUtils, IERC20} from "../../../../utils/TokenUtils.sol";

library BalancerUtils {
    using TokenUtils for IERC20;

    /// @notice Special handling for ETH because UNDERLYING_TOKEN == address(0)
    /// and Balancer uses WETH
    function getTokenAddress(address token) internal pure returns (address) {
        return token == Deployments.ETH_ADDRESS ? address(Deployments.WETH) : address(token);
    }

    function _getTimeWeightedOraclePrice(
        address pool,
        IPriceOracle.Variable variable,
        uint256 secs
    ) internal view returns (uint256) {
        IPriceOracle.OracleAverageQuery[]
            memory queries = new IPriceOracle.OracleAverageQuery[](1);

        queries[0].variable = variable;
        queries[0].secs = secs;
        queries[0].ago = 0; // now

        // Gets the balancer time weighted average price denominated in the first token
        return IPriceOracle(pool).getTimeWeightedAverage(queries)[0];
    }

    /// @notice Normalizes balances to 1e18 (used by Balancer price oracle functions)
    function _normalizeBalances(
        uint256 primaryBalance,
        uint8 primaryDecimals,
        uint256 secondaryBalance,
        uint8 secondaryDecimals
    ) internal pure returns (uint256 normalizedPrimary, uint256 normalizedSecondary) {
        if (primaryDecimals == 18) {
            normalizedPrimary = primaryBalance;
        } else {
            uint256 decimalAdjust;
            unchecked {
                decimalAdjust = 10**(18 - primaryDecimals);
            }
            normalizedPrimary = primaryBalance * decimalAdjust;
        }

        if (secondaryDecimals == 18) {
            normalizedSecondary = secondaryBalance;
        } else {
            uint256 decimalAdjust;
            unchecked {
                decimalAdjust = 10**(18 - secondaryDecimals);
            }
            normalizedSecondary = secondaryBalance * decimalAdjust;
        }
    }

    /// @notice Joins a balancer pool using exact tokens in
    function _joinPoolExactTokensIn(
        PoolContext memory context,
        PoolParams memory params,
        uint256 minBPT
    ) internal returns (uint256 bptAmount) {
        bptAmount = IERC20(address(context.pool)).balanceOf(address(this));
        Deployments.BALANCER_VAULT.joinPool{value: params.msgValue}(
            context.poolId,
            address(this),
            address(this),
            IBalancerVault.JoinPoolRequest(
                params.assets,
                params.amounts,
                abi.encode(
                    IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                    params.amounts,
                    minBPT // Apply minBPT to prevent front running
                ),
                false // Don't use internal balances
            )
        );
        bptAmount =
            IERC20(address(context.pool)).balanceOf(address(this)) -
            bptAmount;
    }

    /// @notice Exits a balancer pool using exact BPT in
    function _exitPoolExactBPTIn(
        PoolContext memory context,
        PoolParams memory params,
        uint256 bptExitAmount
    ) internal returns (uint256[] memory exitBalances) {
        uint256 numAssets = params.assets.length;
        exitBalances = new uint256[](numAssets);

        for (uint256 i; i < numAssets; i++) {
            exitBalances[i] = TokenUtils.tokenBalance(address(params.assets[i]));
        }

        Deployments.BALANCER_VAULT.exitPool(
            context.poolId,
            address(this),
            payable(address(this)), // Vault will receive the underlying assets
            IBalancerVault.ExitPoolRequest(
                params.assets,
                params.amounts,
                abi.encode(
                    IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT,
                    bptExitAmount
                ),
                false // Don't use internal balances
            )
        );

        for (uint256 i; i < numAssets; i++) {
            exitBalances[i] = TokenUtils.tokenBalance(address(params.assets[i])) - exitBalances[i];
        }
    }

    function _swapGivenIn(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 limit
    ) internal returns (uint256 amountOut) {
        amountOut = IERC20(tokenOut).balanceOf(address(this));
        Deployments.BALANCER_VAULT.swap({
            singleSwap: IBalancerVault.SingleSwap({
                poolId: poolId,
                kind: IBalancerVault.SwapKind.GIVEN_IN,
                assetIn: IAsset(tokenIn),
                assetOut: IAsset(tokenOut),
                amount: amountIn,
                userData: new bytes(0)
            }),
            funds: IBalancerVault.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            }),
            limit: limit,
            deadline: block.timestamp
        });
        amountOut = IERC20(tokenOut).balanceOf(address(this)) - amountOut;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;

/**
 * @title EIP20NonStandardInterface
 * @dev Version of ERC20 with no return values for `transfer` and `transferFrom`
 *  See https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
 */
interface IEIP20NonStandard {

    /**
     * @notice Get the total number of tokens in circulation
     * @return The supply of tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transfer` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Transfer `amount` tokens from `msg.sender` to `dst`
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      */
    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transferFrom` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Transfer `amount` tokens from `src` to `dst`
      * @param src The address of the source account
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      */
    function transferFrom(address src, address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `approve` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Approve `spender` to transfer up to `amount` from `src`
      * @dev This will overwrite the approval amount for `spender`
      *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
      * @param spender The address of the account which may transfer tokens
      * @param amount The number of tokens that are approved
      */
    function approve(address spender, uint256 amount) external;

    /**
      * @notice Get the current allowance from `owner` for `spender`
      * @param owner The address of the account which owns the tokens to be spent
      * @param spender The address of the account which may transfer tokens
      * @return remaining The number of tokens allowed to be spent
      */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract nProxy is ERC1967Proxy {
    constructor(
        address _logic,
        bytes memory _data
    ) ERC1967Proxy(_logic, _data) {}

    receive() external payable override {
        // Allow ETH transfers to succeed
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity ^0.8.0;

import "../Proxy.sol";
import "./ERC1967Upgrade.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializing the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) payable {
        _upgradeToAndCall(_logic, _data, false);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return ERC1967Upgrade._getImplementation();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/draft-IERC1822.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {AuraStakingContext} from "../../BalancerVaultTypes.sol";

library AuraStakingUtils {
    function _isValidRewardToken(AuraStakingContext memory context, address token)
        internal pure returns (bool) {
        uint256 len = context.rewardTokens.length;
        for (uint256 i; i < len; i++) {
            if (address(context.rewardTokens[i]) == token) return true;
        }
        return false;
    }
}