// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../utils/SafeDecimalMath.sol";

import "../interfaces/IPrimaryMarketV3.sol";
import "../interfaces/IFundV3.sol";
import "../interfaces/IFundForPrimaryMarketV4.sol";
import "../interfaces/ITrancheIndexV2.sol";
import "../interfaces/IWrappedERC20.sol";

contract PrimaryMarketV4 is IPrimaryMarketV3, ReentrancyGuard, ITrancheIndexV2, Ownable {
    event Created(address indexed account, uint256 underlying, uint256 outQ);
    event Redeemed(address indexed account, uint256 inQ, uint256 underlying, uint256 feeQ);
    event Split(address indexed account, uint256 inQ, uint256 outB, uint256 outR);
    event Merged(
        address indexed account,
        uint256 outQ,
        uint256 inB,
        uint256 inR,
        uint256 feeUnderlying
    );
    event RedemptionQueued(address indexed account, uint256 index, uint256 underlying);
    event RedemptionPopped(uint256 count, uint256 newHead, uint256 requiredUnderlying);
    event RedemptionClaimed(address indexed account, uint256 index, uint256 underlying);
    event FundCapUpdated(uint256 newCap);
    event RedemptionFeeRateUpdated(uint256 newRedemptionFeeRate);
    event MergeFeeRateUpdated(uint256 newMergeFeeRate);

    using SafeMath for uint256;
    using SafeDecimalMath for uint256;
    using SafeERC20 for IERC20;

    struct QueuedRedemption {
        address account;
        uint256 underlying;
        uint256 previousPrefixSum;
    }

    uint256 private constant MAX_REDEMPTION_FEE_RATE = 0.01e18;
    uint256 private constant MAX_MERGE_FEE_RATE = 0.01e18;

    address public immutable override fund;
    bool public immutable redemptionFlag;
    IERC20 private immutable _tokenUnderlying;

    uint256 public redemptionFeeRate;
    uint256 public mergeFeeRate;

    /// @notice The upper limit of underlying that the fund can hold. This contract rejects
    ///         creations that may break this limit.
    /// @dev This limit can be bypassed if the fund has multiple primary markets.
    ///
    ///      Set it to uint(-1) to skip the check and save gas.
    uint256 public fundCap;

    /// @notice Queue of redemptions that cannot be claimed yet. Key is a sequential index
    ///         starting from zero. Value is a tuple of user address, redeemed underlying and
    ///         prefix sum before this entry.
    mapping(uint256 => QueuedRedemption) public queuedRedemptions;

    /// @notice Total underlying tokens of claimable queued redemptions.
    uint256 public claimableUnderlying;

    /// @notice Index of the redemption queue head. All redemptions with index smaller than
    ///         this value can be claimed now.
    uint256 public redemptionQueueHead;

    /// @notice Index of the redemption following the last entry of the queue. The next queued
    ///         redemption will be written at this index.
    uint256 public redemptionQueueTail;

    constructor(
        address fund_,
        uint256 redemptionFeeRate_,
        uint256 mergeFeeRate_,
        uint256 fundCap_,
        bool redemptionFlag_
    ) public Ownable() {
        fund = fund_;
        _tokenUnderlying = IERC20(IFundV3(fund_).tokenUnderlying());
        _updateRedemptionFeeRate(redemptionFeeRate_);
        _updateMergeFeeRate(mergeFeeRate_);
        _updateFundCap(fundCap_);
        redemptionFlag = redemptionFlag_;
    }

    /// @notice Calculate the result of a creation.
    /// @param underlying Underlying amount spent for the creation
    /// @return outQ Created QUEEN amount
    function getCreation(uint256 underlying) public view override returns (uint256 outQ) {
        uint256 fundUnderlying = IFundV3(fund).getTotalUnderlying();
        uint256 fundEquivalentTotalQ = IFundV3(fund).getEquivalentTotalQ();
        require(fundUnderlying.add(underlying) <= fundCap, "Exceed fund cap");
        if (fundEquivalentTotalQ == 0) {
            outQ = underlying.mul(IFundV3(fund).underlyingDecimalMultiplier());
            uint256 splitRatio = IFundV3(fund).splitRatio();
            require(splitRatio != 0, "Fund is not initialized");
            uint256 settledDay = IFundV3(fund).currentDay() - 1 days;
            uint256 underlyingPrice = IFundV3(fund).twapOracle().getTwap(settledDay);
            (uint256 navB, uint256 navR) = IFundV3(fund).historicalNavs(settledDay);
            outQ = outQ.mul(underlyingPrice).div(splitRatio).divideDecimal(navB.add(navR));
        } else {
            require(
                fundUnderlying != 0,
                "Cannot create QUEEN for fund with shares but no underlying"
            );
            outQ = underlying.mul(fundEquivalentTotalQ).div(fundUnderlying);
        }
    }

    /// @notice Calculate the amount of underlying tokens to create at least the given QUEEN amount.
    ///         This only works with non-empty fund for simplicity.
    /// @param minOutQ Minimum received QUEEN amount
    /// @return underlying Underlying amount that should be used for creation
    function getCreationForQ(uint256 minOutQ) external view override returns (uint256 underlying) {
        // Assume:
        //   minOutQ * fundUnderlying = a * fundEquivalentTotalQ - b
        // where a and b are integers and 0 <= b < fundEquivalentTotalQ
        // Then
        //   underlying = a
        //   getCreation(underlying)
        //     = floor(a * fundEquivalentTotalQ / fundUnderlying)
        //    >= floor((a * fundEquivalentTotalQ - b) / fundUnderlying)
        //     = minOutQ
        //   getCreation(underlying - 1)
        //     = floor((a * fundEquivalentTotalQ - fundEquivalentTotalQ) / fundUnderlying)
        //     < (a * fundEquivalentTotalQ - b) / fundUnderlying
        //     = minOutQ
        uint256 fundUnderlying = IFundV3(fund).getTotalUnderlying();
        uint256 fundEquivalentTotalQ = IFundV3(fund).getEquivalentTotalQ();
        require(fundEquivalentTotalQ > 0, "Cannot calculate creation for empty fund");
        return minOutQ.mul(fundUnderlying).add(fundEquivalentTotalQ - 1).div(fundEquivalentTotalQ);
    }

    function _getRedemption(uint256 inQ) private view returns (uint256 underlying) {
        uint256 fundUnderlying = IFundV3(fund).getTotalUnderlying();
        uint256 fundEquivalentTotalQ = IFundV3(fund).getEquivalentTotalQ();
        underlying = inQ.mul(fundUnderlying).div(fundEquivalentTotalQ);
    }

    /// @notice Calculate the result of a redemption.
    /// @param inQ QUEEN amount spent for the redemption
    /// @return underlying Redeemed underlying amount
    /// @return feeQ QUEEN amount charged as redemption fee
    function getRedemption(uint256 inQ)
        public
        view
        override
        returns (uint256 underlying, uint256 feeQ)
    {
        feeQ = inQ.multiplyDecimal(redemptionFeeRate);
        underlying = _getRedemption(inQ - feeQ);
    }

    /// @notice Calculate the amount of QUEEN that can be redeemed for at least the given amount
    ///         of underlying tokens.
    /// @dev The return value may not be the minimum solution due to rounding errors.
    /// @param minUnderlying Minimum received underlying amount
    /// @return inQ QUEEN amount that should be redeemed
    function getRedemptionForUnderlying(uint256 minUnderlying)
        external
        view
        override
        returns (uint256 inQ)
    {
        // Assume:
        //   minUnderlying * fundEquivalentTotalQ = a * fundUnderlying - b
        //   a * 1e18 = c * (1e18 - redemptionFeeRate) + d
        // where
        //   a, b, c, d are integers
        //   0 <= b < fundUnderlying
        //   0 <= d < 1e18 - redemeptionFeeRate
        // Then
        //   inQAfterFee = a
        //   inQ = c
        //   getRedemption(inQ).underlying
        //     = floor((c - floor(c * redemptionFeeRate / 1e18)) * fundUnderlying / fundEquivalentTotalQ)
        //     = floor(ceil(c * (1e18 - redemptionFeeRate) / 1e18) * fundUnderlying / fundEquivalentTotalQ)
        //     = floor(((c * (1e18 - redemptionFeeRate) + d) / 1e18) * fundUnderlying / fundEquivalentTotalQ)
        //     = floor(a * fundUnderlying / fundEquivalentTotalQ)
        //     => floor((a * fundUnderlying - b) / fundEquivalentTotalQ)
        //     = minUnderlying
        uint256 fundUnderlying = IFundV3(fund).getTotalUnderlying();
        uint256 fundEquivalentTotalQ = IFundV3(fund).getEquivalentTotalQ();
        uint256 inQAfterFee =
            minUnderlying.mul(fundEquivalentTotalQ).add(fundUnderlying - 1).div(fundUnderlying);
        return inQAfterFee.divideDecimal(1e18 - redemptionFeeRate);
    }

    /// @notice Calculate the result of a split.
    /// @param inQ QUEEN amount to be split
    /// @return outB Received BISHOP amount, which is also received ROOK amount
    function getSplit(uint256 inQ) public view override returns (uint256 outB) {
        return inQ.multiplyDecimal(IFundV3(fund).splitRatio());
    }

    /// @notice Calculate the amount of QUEEN that can be split into at least the given amount of
    ///         BISHOP and ROOK.
    /// @param minOutB Received BISHOP amount, which is also received ROOK amount
    /// @return inQ QUEEN amount that should be split
    function getSplitForB(uint256 minOutB) external view override returns (uint256 inQ) {
        uint256 splitRatio = IFundV3(fund).splitRatio();
        return minOutB.mul(1e18).add(splitRatio.sub(1)).div(splitRatio);
    }

    /// @notice Calculate the result of a merge.
    /// @param inB Spent BISHOP amount, which is also spent ROOK amount
    /// @return outQ Received QUEEN amount
    /// @return feeQ QUEEN amount charged as merge fee
    function getMerge(uint256 inB) public view override returns (uint256 outQ, uint256 feeQ) {
        uint256 outQBeforeFee = inB.divideDecimal(IFundV3(fund).splitRatio());
        feeQ = outQBeforeFee.multiplyDecimal(mergeFeeRate);
        outQ = outQBeforeFee.sub(feeQ);
    }

    /// @notice Calculate the amount of BISHOP and ROOK that can be merged into at least
    ///      the given amount of QUEEN.
    /// @dev The return value may not be the minimum solution due to rounding errors.
    /// @param minOutQ Minimum received QUEEN amount
    /// @return inB BISHOP amount that should be merged, which is also spent ROOK amount
    function getMergeForQ(uint256 minOutQ) external view override returns (uint256 inB) {
        // Assume:
        //   minOutQ * 1e18 = a * (1e18 - mergeFeeRate) + b
        //   c = ceil(a * splitRatio / 1e18)
        // where a and b are integers and 0 <= b < 1e18 - mergeFeeRate
        // Then
        //   outQBeforeFee = a
        //   inB = c
        //   getMerge(inB).outQ
        //     = c * 1e18 / splitRatio - floor(c * 1e18 / splitRatio * mergeFeeRate / 1e18)
        //     = ceil(c * 1e18 / splitRatio * (1e18 - mergeFeeRate) / 1e18)
        //    >= ceil(a * (1e18 - mergeFeeRate) / 1e18)
        //     = (a * (1e18 - mergeFeeRate) + b) / 1e18         // because b < 1e18
        //     = minOutQ
        uint256 outQBeforeFee = minOutQ.divideDecimal(1e18 - mergeFeeRate);
        inB = outQBeforeFee.mul(IFundV3(fund).splitRatio()).add(1e18 - 1).div(1e18);
    }

    /// @notice Return index of the first queued redemption that cannot be claimed now.
    ///         Users can use this function to determine which indices can be passed to
    ///         `claimRedemptions()`.
    /// @return Index of the first redemption that cannot be claimed now
    function getNewRedemptionQueueHead() external view returns (uint256) {
        uint256 available = _tokenUnderlying.balanceOf(fund);
        uint256 l = redemptionQueueHead;
        uint256 r = redemptionQueueTail;
        uint256 startPrefixSum = queuedRedemptions[l].previousPrefixSum;
        // overflow is desired
        if (queuedRedemptions[r].previousPrefixSum - startPrefixSum <= available) {
            return r;
        }
        // Iteration count is bounded by log2(tail - head), which is at most 256.
        while (l + 1 < r) {
            uint256 m = (l + r) / 2;
            if (queuedRedemptions[m].previousPrefixSum - startPrefixSum <= available) {
                l = m;
            } else {
                r = m;
            }
        }
        return l;
    }

    /// @notice Search in the redemption queue.
    /// @param account Owner of the redemptions, or zero address to return all redemptions
    /// @param startIndex Redemption index where the search starts, or zero to start from the head
    /// @param maxIterationCount Maximum number of redemptions to be scanned, or zero for no limit
    /// @return indices Indices of found redemptions
    /// @return underlying Total underlying of found redemptions
    function getQueuedRedemptions(
        address account,
        uint256 startIndex,
        uint256 maxIterationCount
    ) external view returns (uint256[] memory indices, uint256 underlying) {
        uint256 head = redemptionQueueHead;
        uint256 tail = redemptionQueueTail;
        if (startIndex == 0) {
            startIndex = head;
        } else {
            require(startIndex >= head && startIndex <= tail, "startIndex out of bound");
        }
        uint256 endIndex = tail;
        if (maxIterationCount != 0 && tail - startIndex > maxIterationCount) {
            endIndex = startIndex + maxIterationCount;
        }
        indices = new uint256[](endIndex - startIndex);
        uint256 count = 0;
        for (uint256 i = startIndex; i < endIndex; i++) {
            if (account == address(0) || queuedRedemptions[i].account == account) {
                indices[count] = i;
                underlying += queuedRedemptions[i].underlying;
                count++;
            }
        }
        if (count != endIndex - startIndex) {
            // Shrink the array
            assembly {
                mstore(indices, count)
            }
        }
    }

    /// @notice Return whether the fund can change its primary market to another contract.
    function canBeRemovedFromFund() external view override returns (bool) {
        return redemptionQueueHead == redemptionQueueTail;
    }

    /// @notice Create QUEEN using underlying tokens. This function should be called by
    ///         a smart contract, which transfers underlying tokens to this contract
    ///         in the same transaction.
    /// @param recipient Address that will receive created QUEEN
    /// @param minOutQ Minimum QUEEN amount to be received
    /// @param version The latest rebalance version
    /// @return outQ Received QUEEN amount
    function create(
        address recipient,
        uint256 minOutQ,
        uint256 version
    ) external override nonReentrant returns (uint256 outQ) {
        uint256 underlying = _tokenUnderlying.balanceOf(address(this)).sub(claimableUnderlying);
        outQ = getCreation(underlying);
        require(outQ >= minOutQ && outQ > 0, "Min QUEEN created");
        IFundForPrimaryMarketV4(fund).primaryMarketMint(TRANCHE_Q, recipient, outQ, version);
        _tokenUnderlying.safeTransfer(fund, underlying);
        emit Created(recipient, underlying, outQ);

        // Call an optional hook in the strategy and ignore errors.
        (bool success, ) =
            IFundV3(fund).strategy().call(abi.encodeWithSignature("onPrimaryMarketCreate()"));
        if (!success) {
            // ignore
        }
    }

    /// @notice Redeem QUEEN to get underlying tokens back. Revert if there are still some
    ///         queued redemptions that cannot be claimed now.
    /// @param recipient Address that will receive redeemed underlying tokens
    /// @param inQ Spent QUEEN amount
    /// @param minUnderlying Minimum amount of underlying tokens to be received
    /// @param version The latest rebalance version
    /// @return underlying Received underlying amount
    function redeem(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) external override nonReentrant returns (uint256 underlying) {
        underlying = _redeem(recipient, inQ, minUnderlying, version);
    }

    /// @notice Redeem QUEEN to get native currency back. The underlying must be wrapped token
    ///         of the native currency. Revert if there are still some queued redemptions that
    ///         cannot be claimed now.
    /// @param recipient Address that will receive redeemed underlying tokens
    /// @param inQ Spent QUEEN amount
    /// @param minUnderlying Minimum amount of underlying tokens to be received
    /// @param version The latest rebalance version
    /// @return underlying Received underlying amount
    function redeemAndUnwrap(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) external override nonReentrant returns (uint256 underlying) {
        underlying = _redeem(address(this), inQ, minUnderlying, version);
        IWrappedERC20(address(_tokenUnderlying)).withdraw(underlying);
        (bool success, ) = recipient.call{value: underlying}("");
        require(success, "Transfer failed");
    }

    function _redeem(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) private allowRedemption returns (uint256 underlying) {
        uint256 feeQ;
        (underlying, feeQ) = getRedemption(inQ);
        IFundForPrimaryMarketV4(fund).primaryMarketBurn(TRANCHE_Q, msg.sender, inQ, version);
        _popRedemptionQueue(0);
        require(underlying >= minUnderlying && underlying > 0, "Min underlying redeemed");
        // Redundant check for user-friendly revert message.
        require(underlying <= _tokenUnderlying.balanceOf(fund), "Not enough underlying in fund");
        IFundForPrimaryMarketV4(fund).primaryMarketTransferUnderlying(recipient, underlying, feeQ);
        emit Redeemed(recipient, inQ, underlying, feeQ);

        // Call an optional hook in the strategy and ignore errors.
        (bool success, ) =
            IFundV3(fund).strategy().call(abi.encodeWithSignature("onPrimaryMarketRedeem()"));
        if (!success) {
            // ignore
        }
    }

    /// @notice Redeem QUEEN and wait in the redemption queue. Redeemed underlying tokens will
    ///         be claimable when the fund has enough balance to pay this redemption and all
    ///         previous ones in the queue.
    /// @param recipient Address that will receive redeemed underlying tokens
    /// @param inQ Spent QUEEN amount
    /// @param minUnderlying Minimum amount of underlying tokens to be received
    /// @param version The latest rebalance version
    /// @return underlying Received underlying amount
    /// @return index Index of the queued redemption
    function queueRedemption(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) external override nonReentrant allowRedemption returns (uint256 underlying, uint256 index) {
        uint256 feeQ;
        (underlying, feeQ) = getRedemption(inQ);
        IFundForPrimaryMarketV4(fund).primaryMarketBurn(TRANCHE_Q, msg.sender, inQ, version);
        require(underlying >= minUnderlying && underlying > 0, "Min underlying redeemed");
        index = redemptionQueueTail;
        QueuedRedemption storage newRedemption = queuedRedemptions[index];
        newRedemption.account = recipient;
        newRedemption.underlying = underlying;
        // overflow is desired
        queuedRedemptions[index + 1].previousPrefixSum =
            newRedemption.previousPrefixSum +
            underlying;
        redemptionQueueTail = index + 1;
        IFundForPrimaryMarketV4(fund).primaryMarketAddDebtAndFee(underlying, feeQ);
        emit Redeemed(recipient, inQ, underlying, feeQ);
        emit RedemptionQueued(recipient, index, underlying);
    }

    /// @notice Remove a given number of redemptions from the front of the redemption queue and
    ///         fetch underlying tokens of these redemptions from the fund. Revert if the fund
    ///         cannot pay these redemptions now.
    /// @param count The number of redemptions to be removed, or zero to completely empty the queue
    function popRedemptionQueue(uint256 count) external nonReentrant {
        _popRedemptionQueue(count);
    }

    function _popRedemptionQueue(uint256 count) private {
        uint256 oldHead = redemptionQueueHead;
        uint256 oldTail = redemptionQueueTail;
        uint256 newHead;
        if (count == 0) {
            if (oldHead == oldTail) {
                return;
            }
            newHead = oldTail;
        } else {
            newHead = oldHead.add(count);
            require(newHead <= oldTail, "Redemption queue out of bound");
        }
        // overflow is desired
        uint256 requiredUnderlying =
            queuedRedemptions[newHead].previousPrefixSum -
                queuedRedemptions[oldHead].previousPrefixSum;
        // Redundant check for user-friendly revert message.
        require(
            requiredUnderlying <= _tokenUnderlying.balanceOf(fund),
            "Not enough underlying in fund"
        );
        claimableUnderlying = claimableUnderlying.add(requiredUnderlying);
        IFundForPrimaryMarketV4(fund).primaryMarketPayDebt(requiredUnderlying);
        redemptionQueueHead = newHead;
        emit RedemptionPopped(newHead - oldHead, newHead, requiredUnderlying);
    }

    /// @notice Claim underlying tokens of queued redemptions. All these redemptions must
    ///         belong to the same account.
    /// @param account Recipient of the redemptions
    /// @param indices Indices of the redemptions in the queue, which must be in increasing order
    /// @return underlying Total claimed underlying amount
    function claimRedemptions(address account, uint256[] calldata indices)
        external
        override
        nonReentrant
        returns (uint256 underlying)
    {
        underlying = _claimRedemptions(account, indices);
        _tokenUnderlying.safeTransfer(account, underlying);
    }

    /// @notice Claim native currency of queued redemptions. The underlying must be wrapped token
    ///         of the native currency. All these redemptions must belong to the same account.
    /// @param account Recipient of the redemptions
    /// @param indices Indices of the redemptions in the queue, which must be in increasing order
    /// @return underlying Total claimed underlying amount
    function claimRedemptionsAndUnwrap(address account, uint256[] calldata indices)
        external
        override
        nonReentrant
        returns (uint256 underlying)
    {
        underlying = _claimRedemptions(account, indices);
        IWrappedERC20(address(_tokenUnderlying)).withdraw(underlying);
        (bool success, ) = account.call{value: underlying}("");
        require(success, "Transfer failed");
    }

    function _claimRedemptions(address account, uint256[] calldata indices)
        private
        returns (uint256 underlying)
    {
        uint256 count = indices.length;
        if (count == 0) {
            return 0;
        }
        uint256 head = redemptionQueueHead;
        if (indices[count - 1] >= head) {
            _popRedemptionQueue(indices[count - 1] - head + 1);
        }
        for (uint256 i = 0; i < count; i++) {
            require(i == 0 || indices[i] > indices[i - 1], "Indices out of order");
            QueuedRedemption storage redemption = queuedRedemptions[indices[i]];
            uint256 redemptionUnderlying = redemption.underlying;
            require(
                redemption.account == account && redemptionUnderlying != 0,
                "Invalid redemption index"
            );
            underlying = underlying.add(redemptionUnderlying);
            emit RedemptionClaimed(account, indices[i], redemptionUnderlying);
            delete queuedRedemptions[indices[i]];
        }
        claimableUnderlying = claimableUnderlying.sub(underlying);
    }

    function split(
        address recipient,
        uint256 inQ,
        uint256 version
    ) external override returns (uint256 outB) {
        outB = getSplit(inQ);
        IFundForPrimaryMarketV4(fund).primaryMarketBurn(TRANCHE_Q, msg.sender, inQ, version);
        IFundForPrimaryMarketV4(fund).primaryMarketMint(TRANCHE_B, recipient, outB, version);
        IFundForPrimaryMarketV4(fund).primaryMarketMint(TRANCHE_R, recipient, outB, version);
        emit Split(recipient, inQ, outB, outB);
    }

    function merge(
        address recipient,
        uint256 inB,
        uint256 version
    ) external override returns (uint256 outQ) {
        uint256 feeQ;
        (outQ, feeQ) = getMerge(inB);
        IFundForPrimaryMarketV4(fund).primaryMarketBurn(TRANCHE_B, msg.sender, inB, version);
        IFundForPrimaryMarketV4(fund).primaryMarketBurn(TRANCHE_R, msg.sender, inB, version);
        IFundForPrimaryMarketV4(fund).primaryMarketMint(TRANCHE_Q, recipient, outQ, version);
        IFundForPrimaryMarketV4(fund).primaryMarketAddDebtAndFee(0, feeQ);
        emit Merged(recipient, outQ, inB, inB, feeQ);
    }

    /// @dev Nothing to do for daily fund settlement.
    function settle(uint256 day) external override onlyFund {}

    function _updateFundCap(uint256 newCap) private {
        fundCap = newCap;
        emit FundCapUpdated(newCap);
    }

    function updateFundCap(uint256 newCap) external onlyOwner {
        _updateFundCap(newCap);
    }

    function _updateRedemptionFeeRate(uint256 newRedemptionFeeRate) private {
        require(newRedemptionFeeRate <= MAX_REDEMPTION_FEE_RATE, "Exceed max redemption fee rate");
        redemptionFeeRate = newRedemptionFeeRate;
        emit RedemptionFeeRateUpdated(newRedemptionFeeRate);
    }

    function updateRedemptionFeeRate(uint256 newRedemptionFeeRate) external onlyOwner {
        _updateRedemptionFeeRate(newRedemptionFeeRate);
    }

    function _updateMergeFeeRate(uint256 newMergeFeeRate) private {
        require(newMergeFeeRate <= MAX_MERGE_FEE_RATE, "Exceed max merge fee rate");
        mergeFeeRate = newMergeFeeRate;
        emit MergeFeeRateUpdated(newMergeFeeRate);
    }

    function updateMergeFeeRate(uint256 newMergeFeeRate) external onlyOwner {
        _updateMergeFeeRate(newMergeFeeRate);
    }

    /// @notice Receive unwrapped transfer from the wrapped token.
    receive() external payable {}

    modifier onlyFund() {
        require(msg.sender == fund, "Only fund");
        _;
    }

    modifier allowRedemption() {
        require(redemptionFlag, "Redemption N/A");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT
//
// Copyright (c) 2019 Synthetix
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
pragma solidity >=0.6.10 <0.8.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

library SafeDecimalMath {
    using SafeMath for uint256;

    /* Number of decimal places in the representations. */
    uint256 private constant decimals = 18;
    uint256 private constant highPrecisionDecimals = 27;

    /* The number representing 1.0. */
    uint256 private constant UNIT = 10**uint256(decimals);

    /* The number representing 1.0 for higher fidelity numbers. */
    uint256 private constant PRECISE_UNIT = 10**uint256(highPrecisionDecimals);
    uint256 private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR =
        10**uint256(highPrecisionDecimals - decimals);

    /**
     * @return The result of multiplying x and y, interpreting the operands as fixed-point
     * decimals.
     *
     * @dev A unit factor is divided out after the product of x and y is evaluated,
     * so that product must be less than 2**256. As this is an integer division,
     * the internal division always rounds down. This helps save on gas. Rounding
     * is more expensive on gas.
     */
    function multiplyDecimal(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return x.mul(y).div(UNIT);
    }

    function multiplyDecimalPrecise(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return x.mul(y).div(PRECISE_UNIT);
    }

    /**
     * @return The result of safely dividing x and y. The return value is a high
     * precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and UNIT must be less than 2**256. As
     * this is an integer division, the result is always rounded down.
     * This helps save on gas. Rounding is more expensive on gas.
     */
    function divideDecimal(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Reintroduce the UNIT factor that will be divided out by y. */
        return x.mul(UNIT).div(y);
    }

    function divideDecimalPrecise(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Reintroduce the UNIT factor that will be divided out by y. */
        return x.mul(PRECISE_UNIT).div(y);
    }

    /**
     * @dev Convert a standard decimal representation to a high precision one.
     */
    function decimalToPreciseDecimal(uint256 i) internal pure returns (uint256) {
        return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
    }

    /**
     * @dev Convert a high precision decimal to a standard decimal representation.
     */
    function preciseDecimalToDecimal(uint256 i) internal pure returns (uint256) {
        uint256 quotientTimesTen = i.mul(10).div(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);

        if (quotientTimesTen % 10 >= 5) {
            quotientTimesTen = quotientTimesTen.add(10);
        }

        return quotientTimesTen.div(10);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, and the max value of
     * uint256 on overflow.
     */
    function saturatingMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        return c / a != b ? type(uint256).max : c;
    }

    function saturatingMultiplyDecimal(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return saturatingMul(x, y).div(UNIT);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;

interface IPrimaryMarketV3 {
    function fund() external view returns (address);

    function getCreation(uint256 underlying) external view returns (uint256 outQ);

    function getCreationForQ(uint256 minOutQ) external view returns (uint256 underlying);

    function getRedemption(uint256 inQ) external view returns (uint256 underlying, uint256 fee);

    function getRedemptionForUnderlying(uint256 minUnderlying) external view returns (uint256 inQ);

    function getSplit(uint256 inQ) external view returns (uint256 outB);

    function getSplitForB(uint256 minOutB) external view returns (uint256 inQ);

    function getMerge(uint256 inB) external view returns (uint256 outQ, uint256 feeQ);

    function getMergeForQ(uint256 minOutQ) external view returns (uint256 inB);

    function canBeRemovedFromFund() external view returns (bool);

    function create(
        address recipient,
        uint256 minOutQ,
        uint256 version
    ) external returns (uint256 outQ);

    function redeem(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) external returns (uint256 underlying);

    function redeemAndUnwrap(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) external returns (uint256 underlying);

    function queueRedemption(
        address recipient,
        uint256 inQ,
        uint256 minUnderlying,
        uint256 version
    ) external returns (uint256 underlying, uint256 index);

    function claimRedemptions(address account, uint256[] calldata indices)
        external
        returns (uint256 underlying);

    function claimRedemptionsAndUnwrap(address account, uint256[] calldata indices)
        external
        returns (uint256 underlying);

    function split(
        address recipient,
        uint256 inQ,
        uint256 version
    ) external returns (uint256 outB);

    function merge(
        address recipient,
        uint256 inB,
        uint256 version
    ) external returns (uint256 outQ);

    function settle(uint256 day) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;
pragma experimental ABIEncoderV2;

import "./ITwapOracleV2.sol";

interface IFundV3 {
    /// @notice A linear transformation matrix that represents a rebalance.
    ///
    ///         ```
    ///             [        1        0        0 ]
    ///         R = [ ratioB2Q  ratioBR        0 ]
    ///             [ ratioR2Q        0  ratioBR ]
    ///         ```
    ///
    ///         Amounts of the three tranches `q`, `b` and `r` can be rebalanced by multiplying the matrix:
    ///
    ///         ```
    ///         [ q', b', r' ] = [ q, b, r ] * R
    ///         ```
    struct Rebalance {
        uint256 ratioB2Q;
        uint256 ratioR2Q;
        uint256 ratioBR;
        uint256 timestamp;
    }

    function tokenUnderlying() external view returns (address);

    function tokenQ() external view returns (address);

    function tokenB() external view returns (address);

    function tokenR() external view returns (address);

    function tokenShare(uint256 tranche) external view returns (address);

    function primaryMarket() external view returns (address);

    function primaryMarketUpdateProposal() external view returns (address, uint256);

    function strategy() external view returns (address);

    function strategyUpdateProposal() external view returns (address, uint256);

    function underlyingDecimalMultiplier() external view returns (uint256);

    function twapOracle() external view returns (ITwapOracleV2);

    function feeCollector() external view returns (address);

    function endOfDay(uint256 timestamp) external pure returns (uint256);

    function trancheTotalSupply(uint256 tranche) external view returns (uint256);

    function trancheBalanceOf(uint256 tranche, address account) external view returns (uint256);

    function trancheAllBalanceOf(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function trancheBalanceVersion(address account) external view returns (uint256);

    function trancheAllowance(
        uint256 tranche,
        address owner,
        address spender
    ) external view returns (uint256);

    function trancheAllowanceVersion(address owner, address spender)
        external
        view
        returns (uint256);

    function trancheTransfer(
        uint256 tranche,
        address recipient,
        uint256 amount,
        uint256 version
    ) external;

    function trancheTransferFrom(
        uint256 tranche,
        address sender,
        address recipient,
        uint256 amount,
        uint256 version
    ) external;

    function trancheApprove(
        uint256 tranche,
        address spender,
        uint256 amount,
        uint256 version
    ) external;

    function getRebalanceSize() external view returns (uint256);

    function getRebalance(uint256 index) external view returns (Rebalance memory);

    function getRebalanceTimestamp(uint256 index) external view returns (uint256);

    function currentDay() external view returns (uint256);

    function splitRatio() external view returns (uint256);

    function historicalSplitRatio(uint256 version) external view returns (uint256);

    function fundActivityStartTime() external view returns (uint256);

    function isFundActive(uint256 timestamp) external view returns (bool);

    function getEquivalentTotalB() external view returns (uint256);

    function getEquivalentTotalQ() external view returns (uint256);

    function historicalEquivalentTotalB(uint256 timestamp) external view returns (uint256);

    function historicalNavs(uint256 timestamp) external view returns (uint256 navB, uint256 navR);

    function extrapolateNav(uint256 price)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function doRebalance(
        uint256 amountQ,
        uint256 amountB,
        uint256 amountR,
        uint256 index
    )
        external
        view
        returns (
            uint256 newAmountQ,
            uint256 newAmountB,
            uint256 newAmountR
        );

    function batchRebalance(
        uint256 amountQ,
        uint256 amountB,
        uint256 amountR,
        uint256 fromIndex,
        uint256 toIndex
    )
        external
        view
        returns (
            uint256 newAmountQ,
            uint256 newAmountB,
            uint256 newAmountR
        );

    function refreshBalance(address account, uint256 targetVersion) external;

    function refreshAllowance(
        address owner,
        address spender,
        uint256 targetVersion
    ) external;

    function shareTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    function shareTransferFrom(
        address spender,
        address sender,
        address recipient,
        uint256 amount
    ) external returns (uint256 newAllowance);

    function shareIncreaseAllowance(
        address sender,
        address spender,
        uint256 addedValue
    ) external returns (uint256 newAllowance);

    function shareDecreaseAllowance(
        address sender,
        address spender,
        uint256 subtractedValue
    ) external returns (uint256 newAllowance);

    function shareApprove(
        address owner,
        address spender,
        uint256 amount
    ) external;

    function historicalUnderlying(uint256 timestamp) external view returns (uint256);

    function getTotalUnderlying() external view returns (uint256);

    function getStrategyUnderlying() external view returns (uint256);

    function getTotalDebt() external view returns (uint256);

    event RebalanceTriggered(
        uint256 indexed index,
        uint256 indexed day,
        uint256 navSum,
        uint256 navB,
        uint256 navROrZero,
        uint256 ratioB2Q,
        uint256 ratioR2Q,
        uint256 ratioBR
    );
    event Settled(uint256 indexed day, uint256 navB, uint256 navR, uint256 interestRate);
    event InterestRateUpdated(uint256 baseInterestRate, uint256 floatingInterestRate);
    event BalancesRebalanced(
        address indexed account,
        uint256 version,
        uint256 balanceQ,
        uint256 balanceB,
        uint256 balanceR
    );
    event AllowancesRebalanced(
        address indexed owner,
        address indexed spender,
        uint256 version,
        uint256 allowanceQ,
        uint256 allowanceB,
        uint256 allowanceR
    );
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;

interface IFundForPrimaryMarketV4 {
    function primaryMarketMint(
        uint256 tranche,
        address account,
        uint256 amount,
        uint256 version
    ) external;

    function primaryMarketBurn(
        uint256 tranche,
        address account,
        uint256 amount,
        uint256 version
    ) external;

    function primaryMarketTransferUnderlying(
        address recipient,
        uint256 amount,
        uint256 feeQ
    ) external;

    function primaryMarketAddDebtAndFee(uint256 amount, uint256 feeQ) external;

    function primaryMarketPayDebt(uint256 amount) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;

/// @notice Amounts of QUEEN, BISHOP and ROOK are sometimes stored in a `uint256[3]` array.
///         This contract defines index of each tranche in this array.
///
///         Solidity does not allow constants to be defined in interfaces. So this contract follows
///         the naming convention of interfaces but is implemented as an `abstract contract`.
abstract contract ITrancheIndexV2 {
    uint256 internal constant TRANCHE_Q = 0;
    uint256 internal constant TRANCHE_B = 1;
    uint256 internal constant TRANCHE_R = 2;

    uint256 internal constant TRANCHE_COUNT = 3;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWrappedERC20 is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;

import "./ITwapOracle.sol";

interface ITwapOracleV2 is ITwapOracle {
    function getLatest() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.10 <0.8.0;

interface ITwapOracle {
    enum UpdateType {PRIMARY, SECONDARY, OWNER, CHAINLINK, UNISWAP_V2}

    function getTwap(uint256 timestamp) external view returns (uint256);
}