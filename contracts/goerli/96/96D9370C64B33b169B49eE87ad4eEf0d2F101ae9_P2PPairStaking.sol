// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "../dependencies/openzeppelin/upgradeability/Initializable.sol";
import "../dependencies/openzeppelin/upgradeability/OwnableUpgradeable.sol";
import "../dependencies/openzeppelin/upgradeability/ReentrancyGuardUpgradeable.sol";
import "../dependencies/yoga-labs/ApeCoinStaking.sol";
import "../interfaces/IP2PPairStaking.sol";
import "../dependencies/openzeppelin/contracts/SafeCast.sol";
import "../interfaces/IAutoCompoundApe.sol";
import "../interfaces/ICApe.sol";
import {IERC721} from "../dependencies/openzeppelin/contracts/IERC721.sol";
import {IERC20, SafeERC20} from "../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {PercentageMath} from "../protocol/libraries/math/PercentageMath.sol";
import {SignatureChecker} from "../dependencies/looksrare/contracts/libraries/SignatureChecker.sol";

contract P2PPairStaking is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IP2PPairStaking
{
    using SafeERC20 for IERC20;
    using PercentageMath for uint256;
    using SafeCast for uint256;

    bytes32 public constant LISTING_ORDER_HASH =
        keccak256(
            "ListingOrder(uint8 stakingType,address offerer,address token,uint256 tokenId,uint256 share,uint256 startTime,uint256 endTime)"
        );
    bytes32 public constant MATCHED_ORDER_HASH =
        keccak256(
            "MatchedOrder(uint8 stakingType,address apeToken,address apeOfferer,uint32 apeTokenId,uint32 apeShare,address bakcOfferer,uint32 bakcTokenId,uint32 bakcShare,address apeCoinOfferer,uint32 apeCoinShare,uint256 apePrincipleAmount)"
        );
    bytes32 internal constant EIP712_DOMAIN =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    address public immutable bayc;
    address public immutable mayc;
    address public immutable bakc;
    address public immutable apeCoin;
    address public immutable cApe;
    ApeCoinStaking public immutable apeCoinStaking;

    bytes32 public DOMAIN_SEPARATOR;
    mapping(bytes32 => bool) public isListingOrderCanceled;
    mapping(bytes32 => MatchedOrder) public matchedOrders;
    mapping(address => uint256) public cApeShareBalance;
    address public matchingOperator;
    uint256 public compoundFee;

    constructor(
        address _bayc,
        address _mayc,
        address _bakc,
        address _apeCoin,
        address _cApe,
        address _apeCoinStaking
    ) {
        bayc = _bayc;
        mayc = _mayc;
        bakc = _bakc;
        apeCoin = _apeCoin;
        cApe = _cApe;
        apeCoinStaking = ApeCoinStaking(_apeCoinStaking);
    }

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN,
                keccak256("ParaSpace"),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        //approve for apeCoinStaking
        uint256 allowance = IERC20(apeCoin).allowance(
            address(this),
            address(apeCoinStaking)
        );
        if (allowance == 0) {
            IERC20(apeCoin).safeApprove(
                address(apeCoinStaking),
                type(uint256).max
            );
        }

        //approve for cApe
        allowance = IERC20(apeCoin).allowance(address(this), cApe);
        if (allowance == 0) {
            IERC20(apeCoin).safeApprove(cApe, type(uint256).max);
        }
    }

    function cancelListing(ListingOrder calldata listingOrder)
        external
        nonReentrant
    {
        require(msg.sender == listingOrder.offerer, "not order offerer");
        bytes32 orderHash = getListingOrderHash(listingOrder);
        require(!isListingOrderCanceled[orderHash], "order already cancel");
        isListingOrderCanceled[orderHash] = true;

        emit OrderCancelled(orderHash, listingOrder.offerer);
    }

    function matchPairStakingList(
        ListingOrder calldata apeOrder,
        ListingOrder calldata apeCoinOrder
    ) external nonReentrant returns (bytes32 orderHash) {
        //1 validate all order
        _validateApeOrder(apeOrder);
        _validateApeCoinOrder(apeCoinOrder);

        //2 check if orders can match
        require(
            apeOrder.stakingType <= StakingType.MAYCStaking,
            "invalid stake type"
        );
        require(
            apeOrder.stakingType == apeCoinOrder.stakingType,
            "orders type match failed"
        );
        require(
            apeOrder.share + apeCoinOrder.share ==
                PercentageMath.PERCENTAGE_FACTOR,
            "orders share match failed"
        );

        //3 transfer token
        IERC721(apeOrder.token).safeTransferFrom(
            apeOrder.offerer,
            address(this),
            apeOrder.tokenId
        );
        uint256 apeAmount = getApeCoinStakingCap(apeOrder.stakingType);
        IERC20(apeCoin).safeTransferFrom(
            apeCoinOrder.offerer,
            address(this),
            apeAmount
        );

        //4 create match order
        MatchedOrder memory matchedOrder = MatchedOrder({
            stakingType: apeOrder.stakingType,
            apeToken: apeOrder.token,
            apeOfferer: apeOrder.offerer,
            apeTokenId: apeOrder.tokenId,
            apeShare: apeOrder.share,
            bakcOfferer: address(0),
            bakcTokenId: 0,
            bakcShare: 0,
            apeCoinOfferer: apeCoinOrder.offerer,
            apeCoinShare: apeCoinOrder.share,
            apePrincipleAmount: apeAmount
        });
        orderHash = getMatchedOrderHash(matchedOrder);
        matchedOrders[orderHash] = matchedOrder;

        //5 stake for ApeCoinStaking
        ApeCoinStaking.SingleNft[]
            memory singleNft = new ApeCoinStaking.SingleNft[](1);
        singleNft[0].tokenId = apeOrder.tokenId;
        singleNft[0].amount = apeAmount.toUint224();
        if (apeOrder.stakingType == StakingType.BAYCStaking) {
            apeCoinStaking.depositBAYC(singleNft);
        } else {
            apeCoinStaking.depositMAYC(singleNft);
        }

        //5 emit event
        emit PairStakingMatched(orderHash);

        return orderHash;
    }

    function matchBAKCPairStakingList(
        ListingOrder calldata apeOrder,
        ListingOrder calldata bakcOrder,
        ListingOrder calldata apeCoinOrder
    ) external nonReentrant returns (bytes32 orderHash) {
        //1 validate all order
        _validateApeOrder(apeOrder);
        _validateBakcOrder(bakcOrder);
        _validateApeCoinOrder(apeCoinOrder);

        //2 check if orders can match
        require(
            apeOrder.stakingType >= StakingType.BAYCPairStaking,
            "invalid stake type"
        );
        require(
            apeOrder.stakingType == bakcOrder.stakingType &&
                apeOrder.stakingType == apeCoinOrder.stakingType,
            "orders type match failed"
        );
        require(
            apeOrder.share + bakcOrder.share + apeCoinOrder.share ==
                PercentageMath.PERCENTAGE_FACTOR,
            "share match failed"
        );

        //3 transfer token
        IERC721(apeOrder.token).safeTransferFrom(
            apeOrder.offerer,
            address(this),
            apeOrder.tokenId
        );
        IERC721(bakcOrder.token).safeTransferFrom(
            bakcOrder.offerer,
            address(this),
            bakcOrder.tokenId
        );
        uint256 apeAmount = getApeCoinStakingCap(apeOrder.stakingType);
        IERC20(apeCoin).safeTransferFrom(
            apeCoinOrder.offerer,
            address(this),
            apeAmount
        );

        //4 create match order
        MatchedOrder memory matchedOrder = MatchedOrder({
            stakingType: apeOrder.stakingType,
            apeToken: apeOrder.token,
            apeOfferer: apeOrder.offerer,
            apeTokenId: apeOrder.tokenId,
            apeShare: apeOrder.share,
            bakcOfferer: bakcOrder.offerer,
            bakcTokenId: bakcOrder.tokenId,
            bakcShare: bakcOrder.share,
            apeCoinOfferer: apeCoinOrder.offerer,
            apeCoinShare: apeCoinOrder.share,
            apePrincipleAmount: apeAmount
        });
        orderHash = getMatchedOrderHash(matchedOrder);
        matchedOrders[orderHash] = matchedOrder;

        //5 stake for ApeCoinStaking
        ApeCoinStaking.PairNftDepositWithAmount[]
            memory _stakingPairs = new ApeCoinStaking.PairNftDepositWithAmount[](
                1
            );
        _stakingPairs[0].mainTokenId = apeOrder.tokenId;
        _stakingPairs[0].bakcTokenId = bakcOrder.tokenId;
        _stakingPairs[0].amount = apeAmount.toUint184();
        ApeCoinStaking.PairNftDepositWithAmount[]
            memory _otherPairs = new ApeCoinStaking.PairNftDepositWithAmount[](
                0
            );
        if (apeOrder.stakingType == StakingType.BAYCPairStaking) {
            apeCoinStaking.depositBAKC(_stakingPairs, _otherPairs);
        } else {
            apeCoinStaking.depositBAKC(_otherPairs, _stakingPairs);
        }

        //5 emit event
        emit PairStakingMatched(orderHash);

        return orderHash;
    }

    function breakUpMatchedOrder(bytes32 orderHash) external nonReentrant {
        MatchedOrder memory order = matchedOrders[orderHash];

        //1 check owner
        require(
            msg.sender == matchingOperator ||
                msg.sender == order.apeOfferer ||
                msg.sender == order.bakcOfferer ||
                msg.sender == order.apeCoinOfferer,
            "no permission to break up"
        );

        //2 claim pending reward
        _claimForMatchedOrderAndCompound(orderHash);

        //3 delete matched order
        delete matchedOrders[orderHash];

        //4 exit from ApeCoinStaking
        if (order.stakingType < StakingType.BAYCPairStaking) {
            ApeCoinStaking.SingleNft[]
                memory _nfts = new ApeCoinStaking.SingleNft[](1);
            _nfts[0].tokenId = order.apeTokenId;
            _nfts[0].amount = order.apePrincipleAmount.toUint224();
            if (order.stakingType == StakingType.BAYCStaking) {
                apeCoinStaking.withdrawSelfBAYC(_nfts);
            } else {
                apeCoinStaking.withdrawSelfMAYC(_nfts);
            }
        } else {
            ApeCoinStaking.PairNftWithdrawWithAmount[]
                memory _nfts = new ApeCoinStaking.PairNftWithdrawWithAmount[](
                    1
                );
            _nfts[0].mainTokenId = order.apeTokenId;
            _nfts[0].bakcTokenId = order.bakcTokenId;
            _nfts[0].amount = order.apePrincipleAmount.toUint184();
            _nfts[0].isUncommit = true;
            ApeCoinStaking.PairNftWithdrawWithAmount[]
                memory _otherPairs = new ApeCoinStaking.PairNftWithdrawWithAmount[](
                    0
                );
            if (order.stakingType == StakingType.BAYCPairStaking) {
                apeCoinStaking.withdrawBAKC(_nfts, _otherPairs);
            } else {
                apeCoinStaking.withdrawBAKC(_otherPairs, _nfts);
            }
        }
        //5 transfer token
        IERC721(order.apeToken).safeTransferFrom(
            address(this),
            order.apeOfferer,
            order.apeTokenId
        );
        IERC20(apeCoin).safeTransfer(
            order.apeCoinOfferer,
            order.apePrincipleAmount
        );
        if (order.stakingType >= StakingType.BAYCPairStaking) {
            IERC721(bakc).safeTransferFrom(
                address(this),
                order.bakcOfferer,
                order.bakcTokenId
            );
        }

        //5 emit event
        emit PairStakingBreakUp(orderHash);
    }

    function claimForMatchedOrderAndCompound(bytes32[] calldata orderHashes)
        external
        nonReentrant
    {
        for (uint256 index = 0; index < orderHashes.length; index++) {
            bytes32 orderHash = orderHashes[index];
            _claimForMatchedOrderAndCompound(orderHash);
        }
    }

    function claimCApeReward(address receiver) external nonReentrant {
        uint256 cApeAmount = pendingCApeReward(msg.sender);
        if (cApeAmount > 0) {
            IAutoCompoundApe(cApe).transfer(receiver, cApeAmount);
            delete cApeShareBalance[msg.sender];

            emit CApeClaimed(msg.sender, receiver, cApeAmount);
        }
    }

    function pendingCApeReward(address user) public view returns (uint256) {
        uint256 amount = 0;
        uint256 shareBalance = cApeShareBalance[user];
        if (shareBalance > 0) {
            amount = ICApe(cApe).getPooledApeByShares(shareBalance);
        }
        return amount;
    }

    function getApeCoinStakingCap(StakingType stakingType)
        public
        view
        returns (uint256)
    {
        (
            ,
            ApeCoinStaking.PoolUI memory baycPool,
            ApeCoinStaking.PoolUI memory maycPool,
            ApeCoinStaking.PoolUI memory bakcPool
        ) = apeCoinStaking.getPoolsUI();

        if (stakingType == StakingType.BAYCStaking) {
            return baycPool.currentTimeRange.capPerPosition;
        } else if (stakingType == StakingType.MAYCStaking) {
            return maycPool.currentTimeRange.capPerPosition;
        } else {
            return bakcPool.currentTimeRange.capPerPosition;
        }
    }

    function getListingOrderHash(ListingOrder calldata order)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    LISTING_ORDER_HASH,
                    order.stakingType,
                    order.offerer,
                    order.token,
                    order.tokenId,
                    order.share,
                    order.startTime,
                    order.endTime
                )
            );
    }

    function getMatchedOrderHash(MatchedOrder memory order)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    MATCHED_ORDER_HASH,
                    order.stakingType,
                    order.apeToken,
                    order.apeOfferer,
                    order.apeTokenId,
                    order.apeShare,
                    order.bakcOfferer,
                    order.bakcTokenId,
                    order.bakcShare,
                    order.apeCoinOfferer,
                    order.apeCoinShare,
                    order.apePrincipleAmount
                )
            );
    }

    function _claimForMatchedOrderAndCompound(bytes32 orderHash) internal {
        MatchedOrder memory order = matchedOrders[orderHash];
        uint256 balanceBefore = IERC20(apeCoin).balanceOf(address(this));
        if (order.stakingType < StakingType.BAYCPairStaking) {
            uint256[] memory _nfts = new uint256[](1);
            _nfts[0] = order.apeTokenId;
            if (order.stakingType == StakingType.BAYCStaking) {
                apeCoinStaking.claimSelfBAYC(_nfts);
            } else {
                apeCoinStaking.claimSelfMAYC(_nfts);
            }
        } else {
            ApeCoinStaking.PairNft[]
                memory _nfts = new ApeCoinStaking.PairNft[](1);
            _nfts[0].mainTokenId = order.apeTokenId;
            _nfts[0].bakcTokenId = order.bakcTokenId;
            ApeCoinStaking.PairNft[]
                memory _otherPairs = new ApeCoinStaking.PairNft[](0);
            if (order.stakingType == StakingType.BAYCPairStaking) {
                apeCoinStaking.claimSelfBAKC(_nfts, _otherPairs);
            } else {
                apeCoinStaking.claimSelfBAKC(_otherPairs, _nfts);
            }
        }
        uint256 balanceAfter = IERC20(apeCoin).balanceOf(address(this));
        uint256 rewardAmount = balanceAfter - balanceBefore;

        uint256 shareBefore = ICApe(cApe).sharesOf(address(this));
        IAutoCompoundApe(cApe).deposit(address(this), rewardAmount);
        uint256 shareAfter = ICApe(cApe).sharesOf(address(this));
        uint256 rewardShare = shareAfter - shareBefore;

        //compound fee
        uint256 _compoundFee = rewardShare.percentMul(compoundFee);
        _depositCApeShareForUser(address(this), _compoundFee);
        rewardShare -= _compoundFee;

        _depositCApeShareForUser(
            order.apeOfferer,
            rewardShare.percentMul(order.apeShare)
        );
        _depositCApeShareForUser(
            order.bakcOfferer,
            rewardShare.percentMul(order.bakcShare)
        );
        _depositCApeShareForUser(
            order.apeCoinOfferer,
            rewardShare.percentMul(order.apeCoinShare)
        );

        emit OrderClaimedAndCompounded(orderHash, rewardAmount);
    }

    function _depositCApeShareForUser(address user, uint256 amount) internal {
        if (amount > 0) {
            cApeShareBalance[user] += amount;
        }
    }

    function _validateOrderBasicInfo(ListingOrder calldata listingOrder)
        internal
        view
    {
        require(
            listingOrder.startTime <= block.timestamp,
            "ape order not start"
        );
        require(listingOrder.endTime >= block.timestamp, "ape offer expired");

        bytes32 orderHash = getListingOrderHash(listingOrder);
        require(!isListingOrderCanceled[orderHash], "order already canceled");

        if (
            msg.sender != listingOrder.offerer && msg.sender != matchingOperator
        ) {
            require(
                _validateOrderSignature(
                    listingOrder.offerer,
                    orderHash,
                    listingOrder.v,
                    listingOrder.r,
                    listingOrder.s
                ),
                "invalid signature"
            );
        }
    }

    function _validateApeOrder(ListingOrder calldata apeOrder) internal view {
        _validateOrderBasicInfo(apeOrder);

        address expectedToken = bayc;
        if (
            apeOrder.stakingType == StakingType.MAYCStaking ||
            apeOrder.stakingType == StakingType.MAYCPairStaking
        ) {
            expectedToken = mayc;
        }
        require(apeOrder.token == expectedToken, "ape order invalid token");
        require(
            IERC721(expectedToken).ownerOf(apeOrder.tokenId) ==
                apeOrder.offerer,
            "ape order invalid owner"
        );
    }

    function _validateBakcOrder(ListingOrder calldata bakcOrder) internal view {
        _validateOrderBasicInfo(bakcOrder);

        require(bakcOrder.token == bakc, "bakc order invalid token");
        require(
            IERC721(bakc).ownerOf(bakcOrder.tokenId) == bakcOrder.offerer,
            "bakc order invalid owner"
        );
    }

    function _validateApeCoinOrder(ListingOrder calldata apeCoinOrder)
        internal
        view
    {
        _validateOrderBasicInfo(apeCoinOrder);
        require(apeCoinOrder.token == apeCoin, "ape coin order invalid token");
    }

    function _validateOrderSignature(
        address signer,
        bytes32 orderHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bool) {
        return
            SignatureChecker.verify(
                orderHash,
                signer,
                v,
                r,
                s,
                DOMAIN_SEPARATOR
            );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setMatchingOperator(address _matchingOperator) external onlyOwner {
        require(_matchingOperator != address(0), "zero address");
        address oldOperator = matchingOperator;
        if (oldOperator != _matchingOperator) {
            matchingOperator = _matchingOperator;
            emit MatchingOperatorUpdated(oldOperator, _matchingOperator);
        }
    }

    function setCompoundFee(uint256 _compoundFee) external onlyOwner {
        require(
            _compoundFee < PercentageMath.HALF_PERCENTAGE_FACTOR,
            "Fee Too High"
        );
        uint256 oldValue = compoundFee;
        if (oldValue != _compoundFee) {
            compoundFee = _compoundFee;
            emit CompoundFeeUpdated(oldValue, _compoundFee);
        }
    }

    function claimCompoundFee(address receiver) external onlyOwner {
        this.claimCApeReward(receiver);
    }

    function rescueERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
        emit RescueERC20(token, to, amount);
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import "../dependencies/openzeppelin/contracts/IERC20.sol";

interface IAutoCompoundApe is IERC20 {
    /**
     * @dev Emitted during deposit()
     * @param user The address of the user deposit for
     * @param amountDeposited The amount being deposit
     * @param amountShare The share being deposit
     **/
    event Deposit(
        address indexed caller,
        address indexed user,
        uint256 amountDeposited,
        uint256 amountShare
    );

    /**
     * @dev Emitted during withdraw()
     * @param user The address of the user
     * @param amountWithdraw The amount being withdraw
     * @param amountShare The share being withdraw
     **/
    event Redeem(
        address indexed user,
        uint256 amountWithdraw,
        uint256 amountShare
    );

    /**
     * @dev Emitted during rescueERC20()
     * @param token The address of the token
     * @param to The address of the recipient
     * @param amount The amount being rescued
     **/
    event RescueERC20(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice deposit an `amount` of ape into compound pool.
     * @param onBehalf The address of user will receive the pool share
     * @param amount The amount of ape to be deposit
     **/
    function deposit(address onBehalf, uint256 amount) external;

    /**
     * @notice withdraw an `amount` of ape from compound pool.
     * @param amount The amount of ape to be withdraw
     **/
    function withdraw(uint256 amount) external;

    /**
     * @notice collect ape reward in ApeCoinStaking and deposit to earn compound interest.
     **/
    function harvestAndCompound() external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import "../dependencies/openzeppelin/contracts/IERC20.sol";

interface IP2PPairStaking {
    enum StakingType {
        BAYCStaking,
        MAYCStaking,
        BAYCPairStaking,
        MAYCPairStaking
    }

    struct ListingOrder {
        StakingType stakingType;
        address offerer;
        address token;
        uint32 tokenId;
        uint32 share;
        uint256 startTime;
        uint256 endTime;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct MatchedOrder {
        StakingType stakingType;
        address apeToken;
        address apeOfferer;
        uint32 apeTokenId;
        uint32 apeShare;
        address bakcOfferer;
        uint32 bakcTokenId;
        uint32 bakcShare;
        address apeCoinOfferer;
        uint32 apeCoinShare;
        uint256 apePrincipleAmount;
    }

    /**
     * @dev Emit an event whenever an listing order is successfully cancelled.
     * @param orderHash The hash of the cancelled order.
     * @param offerer   The offerer of the cancelled order.
     */
    event OrderCancelled(bytes32 orderHash, address indexed offerer);

    /**
     * @dev Emitted when a order matched.
     * @param orderHash The hash of the matched order
     **/
    event PairStakingMatched(bytes32 orderHash);

    /**
     * @dev Emitted when a matched order break up.
     * @param orderHash The hash of the break up order
     **/
    event PairStakingBreakUp(bytes32 orderHash);

    /**
     * @dev Emitted when user claimed pending cApe reward.
     * @param user The address of the user
     * @param receiver The address of the cApe receiver
     * @param amount The amount of the cApe been claimed
     **/
    event CApeClaimed(address user, address receiver, uint256 amount);

    /**
     * @dev Emitted when we claimed pending reward for matched order and compound.
     * @param orderHash The hash of the break up order
     **/
    event OrderClaimedAndCompounded(bytes32 orderHash, uint256 totalReward);

    /**
     * @dev Emitted during rescueERC20()
     * @param token The address of the token
     * @param to The address of the recipient
     * @param amount The amount being rescued
     **/
    event RescueERC20(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev Emitted during setMatchingOperator()
     * @param oldOperator The address of the old matching operator
     * @param newOperator The address of the new matching operator
     **/
    event MatchingOperatorUpdated(address oldOperator, address newOperator);

    /**
     * @dev Emitted during setCompoundFee()
     * @param oldFee The value of the old compound fee
     * @param newFee The value of the new compound fee
     **/
    event CompoundFeeUpdated(uint256 oldFee, uint256 newFee);

    /**
     * @notice Cancel a listing order, order canceled cannot be matched.
     * @param listingOrder the detail info of the order to be canceled
     */
    function cancelListing(ListingOrder calldata listingOrder) external;

    /**
     * @notice match an apeOrder with an apeCoinOrder to pair staking
     * @param apeOrder the ape owner's listing order
     * @param apeCoinOrder the Ape Coin owner's listing order
     * @return orderHash matched order hash
     */
    function matchPairStakingList(
        ListingOrder calldata apeOrder,
        ListingOrder calldata apeCoinOrder
    ) external returns (bytes32 orderHash);

    /**
     * @notice match an apeOrder, an bakcOrder with an apeCoinOrder to pair staking
     * @param apeOrder the ape owner's listing order
     * @param bakcOrder the bakc owner's listing order
     * @param apeCoinOrder the Ape Coin owner's listing order
     * @return orderHash matched order hash
     */
    function matchBAKCPairStakingList(
        ListingOrder calldata apeOrder,
        ListingOrder calldata bakcOrder,
        ListingOrder calldata apeCoinOrder
    ) external returns (bytes32 orderHash);

    /**
     * @notice break up an matched pair staking order, only participant of the matched order can call.
     * @param orderHash the hash of the matched order to be break up
     */
    function breakUpMatchedOrder(bytes32 orderHash) external;

    /**
     * @notice claim pending reward for matched pair staking orders and deposit as cApe for user to compound.
     * @param orderHashes the hash of the matched orders to be break up
     */
    function claimForMatchedOrderAndCompound(bytes32[] calldata orderHashes)
        external;

    /**
     * @param user The address of the user
     * @return amount Returns the amount of cApe owned by user
     */
    function pendingCApeReward(address user)
        external
        view
        returns (uint256 amount);

    /**
     * @notice claim user compounded cApe
     * @param receiver The address of the cApe receiver
     */
    function claimCApeReward(address receiver) external;

    /**
     * @notice get Ape Coin Staking cap for every position.
     * @param stakingType the pair staking type
     * @return Ape Coin Staking cap
     */
    function getApeCoinStakingCap(StakingType stakingType)
        external
        returns (uint256);

    /**
     * @notice set a new matching operator, only owner can call this function
     * @param _matchingOperator The address of the new matching operator
     */
    function setMatchingOperator(address _matchingOperator) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import "../dependencies/openzeppelin/contracts/IERC20.sol";

interface ICApe is IERC20 {
    /**
     * @return the amount of shares that corresponds to `amount` protocol-controlled Ape.
     */
    function getShareByPooledApe(uint256 amount)
        external
        view
        returns (uint256);

    /**
     * @return the amount of Ape that corresponds to `sharesAmount` token shares.
     */
    function getPooledApeByShares(uint256 sharesAmount)
        external
        view
        returns (uint256);

    /**
     * @return the amount of shares belongs to _account.
     */
    function sharesOf(address _account) external view returns (uint256);
}

//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../openzeppelin/contracts/IERC20.sol";
import "../openzeppelin/contracts/SafeERC20.sol";
import "../openzeppelin/contracts/SafeCast.sol";
import "../openzeppelin/contracts/Ownable.sol";
import "../openzeppelin/contracts/ERC721Enumerable.sol";

/**
 * @title ApeCoin Staking Contract
 * @notice Stake ApeCoin across four different pools that release hourly rewards
 * @author HorizenLabs
 */
contract ApeCoinStaking is Ownable {
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @notice State for ApeCoin, BAYC, MAYC, and Pair Pools
    struct Pool {
        uint48 lastRewardedTimestampHour;
        uint16 lastRewardsRangeIndex;
        uint96 stakedAmount;
        uint96 accumulatedRewardsPerShare;
        TimeRange[] timeRanges;
    }

    /// @notice Pool rules valid for a given duration of time.
    /// @dev All TimeRange timestamp values must represent whole hours
    struct TimeRange {
        uint48 startTimestampHour;
        uint48 endTimestampHour;
        uint96 rewardsPerHour;
        uint96 capPerPosition;
    }

    /// @dev Convenience struct for front-end applications
    struct PoolUI {
        uint256 poolId;
        uint256 stakedAmount;
        TimeRange currentTimeRange;
    }

    /// @dev Per address amount and reward tracking
    struct Position {
        uint256 stakedAmount;
        int256 rewardsDebt;
    }
    mapping (address => Position) public addressPosition;

    /// @dev Struct for depositing and withdrawing from the BAYC and MAYC NFT pools
    struct SingleNft {
        uint32 tokenId;
        uint224 amount;
    }
    /// @dev Struct for depositing from the BAKC (Pair) pool
    struct PairNftDepositWithAmount {
        uint32 mainTokenId;
        uint32 bakcTokenId;
        uint184 amount;
    }
    /// @dev Struct for withdrawing from the BAKC (Pair) pool
    struct PairNftWithdrawWithAmount {
        uint32 mainTokenId;
        uint32 bakcTokenId;
        uint184 amount;
        bool isUncommit;
    }
    /// @dev Struct for claiming from an NFT pool
    struct PairNft {
        uint128 mainTokenId;
        uint128 bakcTokenId;
    }
    /// @dev NFT paired status.  Can be used bi-directionally (BAYC/MAYC -> BAKC) or (BAKC -> BAYC/MAYC)
    struct PairingStatus {
        uint248 tokenId;
        bool isPaired;
    }

    // @dev UI focused payload
    struct DashboardStake {
        uint256 poolId;
        uint256 tokenId;
        uint256 deposited;
        uint256 unclaimed;
        uint256 rewards24hr;
        DashboardPair pair;
    }
    /// @dev Sub struct for DashboardStake
    struct DashboardPair {
        uint256 mainTokenId;
        uint256 mainTypePoolId;
    }
    /// @dev Placeholder for pair status, used by ApeCoin Pool
    DashboardPair private NULL_PAIR = DashboardPair(0, 0);

    /// @notice Internal ApeCoin amount for distributing staking reward claims
    IERC20 public immutable apeCoin;
    uint256 private constant APE_COIN_PRECISION = 1e18;
    uint256 private constant MIN_DEPOSIT = 1 * APE_COIN_PRECISION;
    uint256 private constant SECONDS_PER_HOUR = 3600;
    uint256 private constant SECONDS_PER_MINUTE = 60;

    uint256 constant APECOIN_POOL_ID = 0;
    uint256 constant BAYC_POOL_ID = 1;
    uint256 constant MAYC_POOL_ID = 2;
    uint256 constant BAKC_POOL_ID = 3;
    Pool[4] public pools;

    /// @dev NFT contract mapping per pool
    mapping(uint256 => ERC721Enumerable) public nftContracts;
    /// @dev poolId => tokenId => nft position
    mapping(uint256 => mapping(uint256 => Position)) public nftPosition;
    /// @dev main type pool ID: 1: BAYC 2: MAYC => main token ID => bakc token ID
    mapping(uint256 => mapping(uint256 => PairingStatus)) public mainToBakc;
    /// @dev bakc Token ID => main type pool ID: 1: BAYC 2: MAYC => main token ID
    mapping(uint256 => mapping(uint256 => PairingStatus)) public bakcToMain;

    /** Custom Events */
    event UpdatePool(
        uint256 indexed poolId,
        uint256 lastRewardedBlock,
        uint256 stakedAmount,
        uint256 accumulatedRewardsPerShare
    );
    event Deposit(
        address indexed user,
        uint256 amount,
        address recipient
    );
    event DepositNft(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 tokenId
    );
    event DepositPairNft(
        address indexed user,
        uint256 amount,
        uint256 mainTypePoolId,
        uint256 mainTokenId,
        uint256 bakcTokenId
    );
    event Withdraw(
        address indexed user,
        uint256 amount,
        address recipient
    );
    event WithdrawNft(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        address recipient,
        uint256 tokenId
    );
    event WithdrawPairNft(
        address indexed user,
        uint256 amount,
        uint256 mainTypePoolId,
        uint256 mainTokenId,
        uint256 bakcTokenId
    );
    event ClaimRewards(
        address indexed user,
        uint256 amount,
        address recipient
    );
    event ClaimRewardsNft(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 tokenId
    );
    event ClaimRewardsPairNft(
        address indexed user,
        uint256 amount,
        uint256 mainTypePoolId,
        uint256 mainTokenId,
        uint256 bakcTokenId
    );

    error DepositMoreThanOneAPE();
    error InvalidPoolId();
    error StartMustBeGreaterThanEnd();
    error StartNotWholeHour();
    error EndNotWholeHour();
    error StartMustEqualLastEnd();
    error CallerNotOwner();
    error MainTokenNotOwnedOrPaired();
    error BAKCNotOwnedOrPaired();
    error BAKCAlreadyPaired();
    error ExceededCapAmount();
    error NotOwnerOfMain();
    error NotOwnerOfBAKC();
    error ProvidedTokensNotPaired();
    error ExceededStakedAmount();
    error NeitherTokenInPairOwnedByCaller();
    error SplitPairCantPartiallyWithdraw();
    error UncommitWrongParameters();

    /**
     * @notice Construct a new ApeCoinStaking instance
     * @param _apeCoinContractAddress The ApeCoin ERC20 contract address
     * @param _baycContractAddress The BAYC NFT contract address
     * @param _maycContractAddress The MAYC NFT contract address
     * @param _bakcContractAddress The BAKC NFT contract address
     */
    constructor(
        address _apeCoinContractAddress,
        address _baycContractAddress,
        address _maycContractAddress,
        address _bakcContractAddress
    ) {
        apeCoin = IERC20(_apeCoinContractAddress);
        nftContracts[BAYC_POOL_ID] = ERC721Enumerable(_baycContractAddress);
        nftContracts[MAYC_POOL_ID] = ERC721Enumerable(_maycContractAddress);
        nftContracts[BAKC_POOL_ID] = ERC721Enumerable(_bakcContractAddress);
    }

    // Deposit/Commit Methods

    /**
     * @notice Deposit ApeCoin to the ApeCoin Pool
     * @param _amount Amount in ApeCoin
     * @param _recipient Address the deposit it stored to
     * @dev ApeCoin deposit must be >= 1 ApeCoin
     */
    function depositApeCoin(uint256 _amount, address _recipient) public {
        if (_amount < MIN_DEPOSIT) revert DepositMoreThanOneAPE();
        updatePool(APECOIN_POOL_ID);

        Position storage position = addressPosition[_recipient];
        _deposit(APECOIN_POOL_ID, position, _amount);

        apeCoin.transferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount, _recipient);
    }

    /**
     * @notice Deposit ApeCoin to the ApeCoin Pool
     * @param _amount Amount in ApeCoin
     * @dev Deposit on behalf of msg.sender. ApeCoin deposit must be >= 1 ApeCoin
     */
    function depositSelfApeCoin(uint256 _amount) external {
        depositApeCoin(_amount, msg.sender);
    }

    /**
     * @notice Deposit ApeCoin to the BAYC Pool
     * @param _nfts Array of SingleNft structs
     * @dev Commits 1 or more BAYC NFTs, each with an ApeCoin amount to the BAYC pool.\
     * Each BAYC committed must attach an ApeCoin amount >= 1 ApeCoin and <= the BAYC pool cap amount.
     */
    function depositBAYC(SingleNft[] calldata _nfts) external {
        _depositNft(BAYC_POOL_ID, _nfts);
    }

    /**
     * @notice Deposit ApeCoin to the MAYC Pool
     * @param _nfts Array of SingleNft structs
     * @dev Commits 1 or more MAYC NFTs, each with an ApeCoin amount to the MAYC pool.\
     * Each MAYC committed must attach an ApeCoin amount >= 1 ApeCoin and <= the MAYC pool cap amount.
     */
    function depositMAYC(SingleNft[] calldata _nfts) external {
        _depositNft(MAYC_POOL_ID, _nfts);
    }

    /**
     * @notice Deposit ApeCoin to the Pair Pool, where Pair = (BAYC + BAKC) or (MAYC + BAKC)
     * @param _baycPairs Array of PairNftDepositWithAmount structs
     * @param _maycPairs Array of PairNftDepositWithAmount structs
     * @dev Commits 1 or more Pairs, each with an ApeCoin amount to the Pair pool.\
     * Each BAKC committed must attach an ApeCoin amount >= 1 ApeCoin and <= the Pair pool cap amount.\
     * Example 1: BAYC + BAKC + 1 ApeCoin:  [[0, 0, "1000000000000000000"],[]]\
     * Example 2: MAYC + BAKC + 1 ApeCoin:  [[], [0, 0, "1000000000000000000"]]\
     * Example 3: (BAYC + BAKC + 1 ApeCoin) and (MAYC + BAKC + 1 ApeCoin): [[0, 0, "1000000000000000000"], [0, 1, "1000000000000000000"]]
     */
    function depositBAKC(PairNftDepositWithAmount[] calldata _baycPairs, PairNftDepositWithAmount[] calldata _maycPairs) external {
        updatePool(BAKC_POOL_ID);
        _depositPairNft(BAYC_POOL_ID, _baycPairs);
        _depositPairNft(MAYC_POOL_ID, _maycPairs);
    }

    // Claim Rewards Methods

    /**
     * @notice Claim rewards for msg.sender and send to recipient
     * @param _recipient Address to send claim reward to
     */
    function claimApeCoin(address _recipient) public {
        updatePool(APECOIN_POOL_ID);

        Position storage position = addressPosition[msg.sender];
        uint256 rewardsToBeClaimed = _claim(APECOIN_POOL_ID, position, _recipient);

        emit ClaimRewards(msg.sender, rewardsToBeClaimed, _recipient);
    }

    /// @notice Claim and send rewards
    function claimSelfApeCoin() external {
        claimApeCoin(msg.sender);
    }

    /**
     * @notice Claim rewards for array of BAYC NFTs and send to recipient
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     * @param _recipient Address to send claim reward to
     */
    function claimBAYC(uint256[] calldata _nfts, address _recipient) external {
        _claimNft(BAYC_POOL_ID, _nfts, _recipient);
    }

    /**
     * @notice Claim rewards for array of BAYC NFTs
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     */
    function claimSelfBAYC(uint256[] calldata _nfts) external {
        _claimNft(BAYC_POOL_ID, _nfts, msg.sender);
    }

    /**
     * @notice Claim rewards for array of MAYC NFTs and send to recipient
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     * @param _recipient Address to send claim reward to
     */
    function claimMAYC(uint256[] calldata _nfts, address _recipient) external {
        _claimNft(MAYC_POOL_ID, _nfts, _recipient);
    }

    /**
     * @notice Claim rewards for array of MAYC NFTs
     * @param _nfts Array of NFTs owned and committed by the msg.sender
     */
    function claimSelfMAYC(uint256[] calldata _nfts) external {
        _claimNft(MAYC_POOL_ID, _nfts, msg.sender);
    }

    /**
     * @notice Claim rewards for array of Paired NFTs and send to recipient
     * @param _baycPairs Array of Paired BAYC NFTs owned and committed by the msg.sender
     * @param _maycPairs Array of Paired MAYC NFTs owned and committed by the msg.sender
     * @param _recipient Address to send claim reward to
     */
    function claimBAKC(PairNft[] calldata _baycPairs, PairNft[] calldata _maycPairs, address _recipient) public {
        updatePool(BAKC_POOL_ID);
        _claimPairNft(BAYC_POOL_ID, _baycPairs, _recipient);
        _claimPairNft(MAYC_POOL_ID, _maycPairs, _recipient);
    }

    /**
     * @notice Claim rewards for array of Paired NFTs
     * @param _baycPairs Array of Paired BAYC NFTs owned and committed by the msg.sender
     * @param _maycPairs Array of Paired MAYC NFTs owned and committed by the msg.sender
     */
    function claimSelfBAKC(PairNft[] calldata _baycPairs, PairNft[] calldata _maycPairs) external {
        claimBAKC(_baycPairs, _maycPairs, msg.sender);
    }

    // Uncommit/Withdraw Methods

    /**
     * @notice Withdraw staked ApeCoin from the ApeCoin pool.  Performs an automatic claim as part of the withdraw process.
     * @param _amount Amount of ApeCoin
     * @param _recipient Address to send withdraw amount and claim to
     */
    function withdrawApeCoin(uint256 _amount, address _recipient) public {
        updatePool(APECOIN_POOL_ID);

        Position storage position = addressPosition[msg.sender];
        if (_amount == position.stakedAmount) {
            uint256 rewardsToBeClaimed = _claim(APECOIN_POOL_ID, position, _recipient);
            emit ClaimRewards(msg.sender, rewardsToBeClaimed, _recipient);
        }
        _withdraw(APECOIN_POOL_ID, position, _amount);

        apeCoin.transfer(_recipient, _amount);

        emit Withdraw(msg.sender, _amount, _recipient);
    }

    /**
     * @notice Withdraw staked ApeCoin from the ApeCoin pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _amount Amount of ApeCoin
     */
    function withdrawSelfApeCoin(uint256 _amount) external {
        withdrawApeCoin(_amount, msg.sender);
    }

    /**
     * @notice Withdraw staked ApeCoin from the BAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of BAYC NFT's with staked amounts
     * @param _recipient Address to send withdraw amount and claim to
     */
    function withdrawBAYC(SingleNft[] calldata _nfts, address _recipient) external {
        _withdrawNft(BAYC_POOL_ID, _nfts, _recipient);
    }

    /**
     * @notice Withdraw staked ApeCoin from the BAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of BAYC NFT's with staked amounts
     */
    function withdrawSelfBAYC(SingleNft[] calldata _nfts) external {
        _withdrawNft(BAYC_POOL_ID, _nfts, msg.sender);
    }

    /**
     * @notice Withdraw staked ApeCoin from the MAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of MAYC NFT's with staked amounts
     * @param _recipient Address to send withdraw amount and claim to
     */
    function withdrawMAYC(SingleNft[] calldata _nfts, address _recipient) external {
        _withdrawNft(MAYC_POOL_ID, _nfts, _recipient);
    }

    /**
     * @notice Withdraw staked ApeCoin from the MAYC pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _nfts Array of MAYC NFT's with staked amounts
     */
    function withdrawSelfMAYC(SingleNft[] calldata _nfts) external {
        _withdrawNft(MAYC_POOL_ID, _nfts, msg.sender);
    }

    /**
     * @notice Withdraw staked ApeCoin from the Pair pool.  If withdraw is total staked amount, performs an automatic claim.
     * @param _baycPairs Array of Paired BAYC NFT's with staked amounts and isUncommit boolean
     * @param _maycPairs Array of Paired MAYC NFT's with staked amounts and isUncommit boolean
     * @dev if pairs have split ownership and BAKC is attempting a withdraw, the withdraw must be for the total staked amount
     */
    function withdrawBAKC(PairNftWithdrawWithAmount[] calldata _baycPairs, PairNftWithdrawWithAmount[] calldata _maycPairs) external {
        updatePool(BAKC_POOL_ID);
        _withdrawPairNft(BAYC_POOL_ID, _baycPairs);
        _withdrawPairNft(MAYC_POOL_ID, _maycPairs);
    }

    // Time Range Methods

    /**
     * @notice Add single time range with a given rewards per hour for a given pool
     * @dev In practice one Time Range will represent one quarter (defined by `_startTimestamp`and `_endTimeStamp` as whole hours)
     * where the rewards per hour is constant for a given pool.
     * @param _poolId Available pool values 0-3
     * @param _amount Total amount of ApeCoin to be distributed over the range
     * @param _startTimestamp Whole hour timestamp representation
     * @param _endTimeStamp Whole hour timestamp representation
     * @param _capPerPosition Per position cap amount determined by poolId
     */
    function addTimeRange(
        uint256 _poolId,
        uint256 _amount,
        uint256 _startTimestamp,
        uint256 _endTimeStamp,
        uint256 _capPerPosition) external onlyOwner
    {
        if (_poolId > BAKC_POOL_ID) revert InvalidPoolId();
        if (_startTimestamp >= _endTimeStamp) revert StartMustBeGreaterThanEnd();
        if (getMinute(_startTimestamp) > 0 || getSecond(_startTimestamp) > 0) revert StartNotWholeHour();
        if (getMinute(_endTimeStamp) > 0 || getSecond(_endTimeStamp) > 0) revert EndNotWholeHour();

        Pool storage pool = pools[_poolId];
        uint256 length = pool.timeRanges.length;
        if (length > 0) {
            if (_startTimestamp != pool.timeRanges[length - 1].endTimestampHour) revert StartMustEqualLastEnd();
        }

        uint256 hoursInSeconds = _endTimeStamp - _startTimestamp;
        uint256 rewardsPerHour = _amount * SECONDS_PER_HOUR / hoursInSeconds;

        TimeRange memory next = TimeRange(_startTimestamp.toUint48(), _endTimeStamp.toUint48(),
            rewardsPerHour.toUint96(), _capPerPosition.toUint96());
        pool.timeRanges.push(next);
    }

    /**
     * @notice Removes the last Time Range for a given pool.
     * @param _poolId Available pool values 0-3
     */
    function removeLastTimeRange(uint256 _poolId) external onlyOwner {
        pools[_poolId].timeRanges.pop();
    }

    /**
     * @notice Lookup method for a TimeRange struct
     * @return TimeRange A Pool's timeRanges struct by index.
     * @param _poolId Available pool values 0-3
     * @param _index Target index in a Pool's timeRanges array
     */
    function getTimeRangeBy(uint256 _poolId, uint256 _index) public view returns (TimeRange memory) {
        return pools[_poolId].timeRanges[_index];
    }

    // Pool Methods

    /**
     * @notice Lookup available rewards for a pool over a given time range
     * @return uint256 The amount of ApeCoin rewards to be distributed by pool for a given time range
     * @return uint256 The amount of time ranges
     * @param _poolId Available pool values 0-3
     * @param _from Whole hour timestamp representation
     * @param _to Whole hour timestamp representation
     */
    function rewardsBy(uint256 _poolId, uint256 _from, uint256 _to) public view returns (uint256, uint256) {
        Pool memory pool = pools[_poolId];

        uint256 currentIndex = pool.lastRewardsRangeIndex;
        if(_to < pool.timeRanges[0].startTimestampHour) return (0, currentIndex);

        while(_from > pool.timeRanges[currentIndex].endTimestampHour && _to > pool.timeRanges[currentIndex].endTimestampHour) {
        unchecked {
            ++currentIndex;
        }
        }

        uint256 rewards;
        TimeRange memory current;
        uint256 startTimestampHour;
        uint256 endTimestampHour;
        uint256 length = pool.timeRanges.length;
        for(uint256 i = currentIndex; i < length;) {
            current = pool.timeRanges[i];
            startTimestampHour = _from <= current.startTimestampHour ? current.startTimestampHour : _from;
            endTimestampHour = _to <= current.endTimestampHour ? _to : current.endTimestampHour;

            rewards = rewards + (endTimestampHour - startTimestampHour) * current.rewardsPerHour / SECONDS_PER_HOUR;

            if(_to <= endTimestampHour) {
                return (rewards, i);
            }
        unchecked {
            ++i;
        }
        }

        return (rewards, length - 1);
    }

    /**
     * @notice Updates reward variables `lastRewardedTimestampHour`, `accumulatedRewardsPerShare` and `lastRewardsRangeIndex`
     * for a given pool.
     * @param _poolId Available pool values 0-3
     */
    function updatePool(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];

        if (block.timestamp < pool.timeRanges[0].startTimestampHour) return;
        if (block.timestamp <= pool.lastRewardedTimestampHour + SECONDS_PER_HOUR) return;

        uint48 lastTimestampHour = pool.timeRanges[pool.timeRanges.length-1].endTimestampHour;
        uint48 previousTimestampHour = getPreviousTimestampHour().toUint48();

        if (pool.stakedAmount == 0) {
            pool.lastRewardedTimestampHour = previousTimestampHour > lastTimestampHour ? lastTimestampHour : previousTimestampHour;
            return;
        }

        (uint256 rewards, uint256 index) = rewardsBy(_poolId, pool.lastRewardedTimestampHour, previousTimestampHour);
        if (pool.lastRewardsRangeIndex != index) {
            pool.lastRewardsRangeIndex = index.toUint16();
        }
        pool.accumulatedRewardsPerShare = (pool.accumulatedRewardsPerShare + (rewards * APE_COIN_PRECISION) / pool.stakedAmount).toUint96();
        pool.lastRewardedTimestampHour = previousTimestampHour > lastTimestampHour ? lastTimestampHour : previousTimestampHour;

        emit UpdatePool(_poolId, pool.lastRewardedTimestampHour, pool.stakedAmount, pool.accumulatedRewardsPerShare);
    }

    // Read Methods

    function getCurrentTimeRangeIndex(Pool memory pool) private view returns (uint256) {
        uint256 current = pool.lastRewardsRangeIndex;

        if (block.timestamp < pool.timeRanges[current].startTimestampHour) return current;
        for(current = pool.lastRewardsRangeIndex; current < pool.timeRanges.length; ++current) {
            TimeRange memory currentTimeRange = pool.timeRanges[current];
            if (currentTimeRange.startTimestampHour <= block.timestamp && block.timestamp <= currentTimeRange.endTimestampHour) return current;
        }
        revert("distribution ended");
    }

    /**
     * @notice Fetches a PoolUI struct (poolId, stakedAmount, currentTimeRange) for each reward pool
     * @return PoolUI for ApeCoin.
     * @return PoolUI for BAYC.
     * @return PoolUI for MAYC.
     * @return PoolUI for BAKC.
     */
    function getPoolsUI() public view returns (PoolUI memory, PoolUI memory, PoolUI memory, PoolUI memory) {
        Pool memory apeCoinPool = pools[0];
        Pool memory baycPool = pools[1];
        Pool memory maycPool = pools[2];
        Pool memory bakcPool = pools[3];
        uint256 current = getCurrentTimeRangeIndex(apeCoinPool);
        return (PoolUI(0,apeCoinPool.stakedAmount, apeCoinPool.timeRanges[current]),
        PoolUI(1,baycPool.stakedAmount, baycPool.timeRanges[current]),
        PoolUI(2,maycPool.stakedAmount, maycPool.timeRanges[current]),
        PoolUI(3,bakcPool.stakedAmount, bakcPool.timeRanges[current]));
    }

    /**
     * @notice Fetches an address total staked amount, used by voting contract
     * @return amount uint256 staked amount for all pools.
     * @param _address An Ethereum address
     */
    function stakedTotal(address _address) external view returns (uint256) {
        uint256 total = addressPosition[_address].stakedAmount;

        total += _stakedTotal(BAYC_POOL_ID, _address);
        total += _stakedTotal(MAYC_POOL_ID, _address);
        total += _stakedTotalPair(_address);

        return total;
    }

    function _stakedTotal(uint256 _poolId, address _addr) private view returns (uint256) {
        uint256 total = 0;
        uint256 nftCount = nftContracts[_poolId].balanceOf(_addr);
        for(uint256 i = 0; i < nftCount; ++i) {
            uint256 tokenId = nftContracts[_poolId].tokenOfOwnerByIndex(_addr, i);
            total += nftPosition[_poolId][tokenId].stakedAmount;
        }

        return total;
    }

    function _stakedTotalPair(address _addr) private view returns (uint256) {
        uint256 total = 0;

        uint256 nftCount = nftContracts[BAYC_POOL_ID].balanceOf(_addr);
        for(uint256 i = 0; i < nftCount; ++i) {
            uint256 baycTokenId = nftContracts[BAYC_POOL_ID].tokenOfOwnerByIndex(_addr, i);
            if (mainToBakc[BAYC_POOL_ID][baycTokenId].isPaired) {
                uint256 bakcTokenId = mainToBakc[BAYC_POOL_ID][baycTokenId].tokenId;
                total += nftPosition[BAKC_POOL_ID][bakcTokenId].stakedAmount;
            }
        }

        nftCount = nftContracts[MAYC_POOL_ID].balanceOf(_addr);
        for(uint256 i = 0; i < nftCount; ++i) {
            uint256 maycTokenId = nftContracts[MAYC_POOL_ID].tokenOfOwnerByIndex(_addr, i);
            if (mainToBakc[MAYC_POOL_ID][maycTokenId].isPaired) {
                uint256 bakcTokenId = mainToBakc[MAYC_POOL_ID][maycTokenId].tokenId;
                total += nftPosition[BAKC_POOL_ID][bakcTokenId].stakedAmount;
            }
        }

        return total;
    }

    /**
     * @notice Fetches a DashboardStake = [poolId, tokenId, deposited, unclaimed, rewards24Hrs, paired] \
     * for each pool, for an Ethereum address
     * @return dashboardStakes An array of DashboardStake structs
     * @param _address An Ethereum address
     */
    function getAllStakes(address _address) public view returns (DashboardStake[] memory) {

        DashboardStake memory apeCoinStake = getApeCoinStake(_address);
        DashboardStake[] memory baycStakes = getBaycStakes(_address);
        DashboardStake[] memory maycStakes = getMaycStakes(_address);
        DashboardStake[] memory bakcStakes = getBakcStakes(_address);
        DashboardStake[] memory splitStakes = getSplitStakes(_address);

        uint256 count = (baycStakes.length + maycStakes.length + bakcStakes.length + splitStakes.length + 1);
        DashboardStake[] memory allStakes = new DashboardStake[](count);

        uint256 offset = 0;
        allStakes[offset] = apeCoinStake;
        ++offset;

        for(uint256 i = 0; i < baycStakes.length; ++i) {
            allStakes[offset] = baycStakes[i];
            ++offset;
        }

        for(uint256 i = 0; i < maycStakes.length; ++i) {
            allStakes[offset] = maycStakes[i];
            ++offset;
        }

        for(uint256 i = 0; i < bakcStakes.length; ++i) {
            allStakes[offset] = bakcStakes[i];
            ++offset;
        }

        for(uint256 i = 0; i < splitStakes.length; ++i) {
            allStakes[offset] = splitStakes[i];
            ++offset;
        }

        return allStakes;
    }

    /**
     * @notice Fetches a DashboardStake for the ApeCoin pool
     * @return dashboardStake A dashboardStake struct
     * @param _address An Ethereum address
     */
    function getApeCoinStake(address _address) public view returns (DashboardStake memory) {
        uint256 tokenId = 0;
        uint256 deposited = addressPosition[_address].stakedAmount;
        uint256 unclaimed = deposited > 0 ? this.pendingRewards(0, _address, tokenId) : 0;
        uint256 rewards24Hrs = deposited > 0 ? _estimate24HourRewards(0, _address, 0) : 0;

        return DashboardStake(APECOIN_POOL_ID, tokenId, deposited, unclaimed, rewards24Hrs, NULL_PAIR);
    }

    /**
     * @notice Fetches an array of DashboardStakes for the BAYC pool
     * @return dashboardStakes An array of DashboardStake structs
     */
    function getBaycStakes(address _address) public view returns (DashboardStake[] memory) {
        return _getStakes(_address, BAYC_POOL_ID);
    }

    /**
     * @notice Fetches an array of DashboardStakes for the MAYC pool
     * @return dashboardStakes An array of DashboardStake structs
     */
    function getMaycStakes(address _address) public view returns (DashboardStake[] memory) {
        return _getStakes(_address, MAYC_POOL_ID);
    }

    /**
     * @notice Fetches an array of DashboardStakes for the BAKC pool
     * @return dashboardStakes An array of DashboardStake structs
     */
    function getBakcStakes(address _address) public view returns (DashboardStake[] memory) {
        return _getStakes(_address, BAKC_POOL_ID);
    }

    /**
     * @notice Fetches an array of DashboardStakes for the Pair Pool when ownership is split \
     * ie (BAYC/MAYC) and BAKC in pair pool have different owners.
     * @return dashboardStakes An array of DashboardStake structs
     * @param _address An Ethereum address
     */
    function getSplitStakes(address _address) public view returns (DashboardStake[] memory) {
        uint256 baycSplits = _getSplitStakeCount(nftContracts[BAYC_POOL_ID].balanceOf(_address), _address, BAYC_POOL_ID);
        uint256 maycSplits = _getSplitStakeCount(nftContracts[MAYC_POOL_ID].balanceOf(_address), _address, MAYC_POOL_ID);
        uint256 totalSplits = baycSplits + maycSplits;

        if(totalSplits == 0) {
            return new DashboardStake[](0);
        }

        DashboardStake[] memory baycSplitStakes = _getSplitStakes(baycSplits, _address, BAYC_POOL_ID);
        DashboardStake[] memory maycSplitStakes = _getSplitStakes(maycSplits, _address, MAYC_POOL_ID);

        DashboardStake[] memory splitStakes = new DashboardStake[](totalSplits);
        uint256 offset = 0;
        for(uint256 i = 0; i < baycSplitStakes.length; ++i) {
            splitStakes[offset] = baycSplitStakes[i];
            ++offset;
        }

        for(uint256 i = 0; i < maycSplitStakes.length; ++i) {
            splitStakes[offset] = maycSplitStakes[i];
            ++offset;
        }

        return splitStakes;
    }

    function _getSplitStakes(uint256 splits, address _address, uint256 _mainPoolId) private view returns (DashboardStake[] memory) {

        DashboardStake[] memory dashboardStakes = new DashboardStake[](splits);
        uint256 counter;

        for(uint256 i = 0; i < nftContracts[_mainPoolId].balanceOf(_address); ++i) {
            uint256 mainTokenId = nftContracts[_mainPoolId].tokenOfOwnerByIndex(_address, i);
            if(mainToBakc[_mainPoolId][mainTokenId].isPaired) {
                uint256 bakcTokenId = mainToBakc[_mainPoolId][mainTokenId].tokenId;
                address currentOwner = nftContracts[BAKC_POOL_ID].ownerOf(bakcTokenId);

                /* Split Pair Check*/
                if (currentOwner != _address) {
                    uint256 deposited = nftPosition[BAKC_POOL_ID][bakcTokenId].stakedAmount;
                    uint256 unclaimed = deposited > 0 ? this.pendingRewards(BAKC_POOL_ID, currentOwner, bakcTokenId) : 0;
                    uint256 rewards24Hrs = deposited > 0 ? _estimate24HourRewards(BAKC_POOL_ID, currentOwner, bakcTokenId): 0;

                    DashboardPair memory pair = NULL_PAIR;
                    if(bakcToMain[bakcTokenId][_mainPoolId].isPaired) {
                        pair = DashboardPair(bakcToMain[bakcTokenId][_mainPoolId].tokenId, _mainPoolId);
                    }

                    DashboardStake memory dashboardStake = DashboardStake(BAKC_POOL_ID, bakcTokenId, deposited, unclaimed, rewards24Hrs, pair);
                    dashboardStakes[counter] = dashboardStake;
                    ++counter;
                }
            }
        }

        return dashboardStakes;
    }

    function _getSplitStakeCount(uint256 nftCount, address _address, uint256 _mainPoolId) private view returns (uint256) {
        uint256 splitCount;
        for(uint256 i = 0; i < nftCount; ++i) {
            uint256 mainTokenId = nftContracts[_mainPoolId].tokenOfOwnerByIndex(_address, i);
            if(mainToBakc[_mainPoolId][mainTokenId].isPaired) {
                uint256 bakcTokenId = mainToBakc[_mainPoolId][mainTokenId].tokenId;
                address currentOwner = nftContracts[BAKC_POOL_ID].ownerOf(bakcTokenId);
                if (currentOwner != _address) {
                    ++splitCount;
                }
            }
        }

        return splitCount;
    }

    function _getStakes(address _address, uint256 _poolId) private view returns (DashboardStake[] memory) {
        uint256 nftCount = nftContracts[_poolId].balanceOf(_address);
        DashboardStake[] memory dashboardStakes = nftCount > 0 ? new DashboardStake[](nftCount) : new DashboardStake[](0);

        if(nftCount == 0) {
            return dashboardStakes;
        }

        for(uint256 i = 0; i < nftCount; ++i) {
            uint256 tokenId = nftContracts[_poolId].tokenOfOwnerByIndex(_address, i);
            uint256 deposited = nftPosition[_poolId][tokenId].stakedAmount;
            uint256 unclaimed = deposited > 0 ? this.pendingRewards(_poolId, _address, tokenId) : 0;
            uint256 rewards24Hrs = deposited > 0 ? _estimate24HourRewards(_poolId, _address, tokenId): 0;

            DashboardPair memory pair = NULL_PAIR;
            if(_poolId == BAKC_POOL_ID) {
                if(bakcToMain[tokenId][BAYC_POOL_ID].isPaired) {
                    pair = DashboardPair(bakcToMain[tokenId][BAYC_POOL_ID].tokenId, BAYC_POOL_ID);
                } else if(bakcToMain[tokenId][MAYC_POOL_ID].isPaired) {
                    pair = DashboardPair(bakcToMain[tokenId][MAYC_POOL_ID].tokenId, MAYC_POOL_ID);
                }
            }

            DashboardStake memory dashboardStake = DashboardStake(_poolId, tokenId, deposited, unclaimed, rewards24Hrs, pair);
            dashboardStakes[i] = dashboardStake;
        }

        return dashboardStakes;
    }

    function _estimate24HourRewards(uint256 _poolId, address _address, uint256 _tokenId) private view returns (uint256) {
        Pool memory pool = pools[_poolId];
        Position memory position = _poolId == 0 ? addressPosition[_address]: nftPosition[_poolId][_tokenId];

        TimeRange memory rewards = getTimeRangeBy(_poolId, pool.lastRewardsRangeIndex);
        return (position.stakedAmount * uint256(rewards.rewardsPerHour) * 24) / uint256(pool.stakedAmount);
    }

    /**
     * @notice Fetches the current amount of claimable ApeCoin rewards for a given position from a given pool.
     * @return uint256 value of pending rewards
     * @param _poolId Available pool values 0-3
     * @param _address Address to lookup Position for
     * @param _tokenId An NFT id
     */
    function pendingRewards(uint256 _poolId, address _address, uint256 _tokenId) external view returns (uint256) {
        Pool memory pool = pools[_poolId];
        Position memory position = _poolId == 0 ? addressPosition[_address]: nftPosition[_poolId][_tokenId];

        (uint256 rewardsSinceLastCalculated,) = rewardsBy(_poolId, pool.lastRewardedTimestampHour, getPreviousTimestampHour());
        uint256 accumulatedRewardsPerShare = pool.accumulatedRewardsPerShare;

        if (block.timestamp > pool.lastRewardedTimestampHour + SECONDS_PER_HOUR && pool.stakedAmount != 0) {
            accumulatedRewardsPerShare = accumulatedRewardsPerShare + rewardsSinceLastCalculated * APE_COIN_PRECISION / pool.stakedAmount;
        }
        return ((position.stakedAmount * accumulatedRewardsPerShare).toInt256() - position.rewardsDebt).toUint256() / APE_COIN_PRECISION;
    }

    // Convenience methods for timestamp calculation

    /// @notice the minutes (0 to 59) of a timestamp
    function getMinute(uint256 timestamp) internal pure returns (uint256 minute) {
        uint256 secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }

    /// @notice the seconds (0 to 59) of a timestamp
    function getSecond(uint256 timestamp) internal pure returns (uint256 second) {
        second = timestamp % SECONDS_PER_MINUTE;
    }

    /// @notice the previous whole hour of a timestamp
    function getPreviousTimestampHour() internal view returns (uint256) {
        return block.timestamp - (getMinute(block.timestamp) * 60 + getSecond(block.timestamp));
    }

    // Private Methods - shared logic
    function _deposit(uint256 _poolId, Position storage _position, uint256 _amount) private {
        Pool storage pool = pools[_poolId];

        _position.stakedAmount += _amount;
        pool.stakedAmount += _amount.toUint96();
        _position.rewardsDebt += (_amount * pool.accumulatedRewardsPerShare).toInt256();
    }

    function _depositNft(uint256 _poolId, SingleNft[] calldata _nfts) private {
        updatePool(_poolId);
        uint256 tokenId;
        uint256 amount;
        Position storage position;
        uint256 length = _nfts.length;
        uint256 totalDeposit;
        for(uint256 i; i < length;) {
            tokenId = _nfts[i].tokenId;
            position = nftPosition[_poolId][tokenId];
            if (position.stakedAmount == 0) {
                if (nftContracts[_poolId].ownerOf(tokenId) != msg.sender) revert CallerNotOwner();
            }
            amount = _nfts[i].amount;
            _depositNftGuard(_poolId, position, amount);
            totalDeposit += amount;
            emit DepositNft(msg.sender, _poolId, amount, tokenId);
            unchecked {
                ++i;
            }
        }
        if (totalDeposit > 0) apeCoin.transferFrom(msg.sender, address(this), totalDeposit);
    }

    function _depositPairNft(uint256 mainTypePoolId, PairNftDepositWithAmount[] calldata _nfts) private {
        uint256 length = _nfts.length;
        uint256 totalDeposit;
        PairNftDepositWithAmount memory pair;
        Position storage position;
        for(uint256 i; i < length;) {
            pair = _nfts[i];
            position = nftPosition[BAKC_POOL_ID][pair.bakcTokenId];

            if(position.stakedAmount == 0) {
                if (nftContracts[mainTypePoolId].ownerOf(pair.mainTokenId) != msg.sender
                    || mainToBakc[mainTypePoolId][pair.mainTokenId].isPaired) revert MainTokenNotOwnedOrPaired();
                if (nftContracts[BAKC_POOL_ID].ownerOf(pair.bakcTokenId) != msg.sender
                    || bakcToMain[pair.bakcTokenId][mainTypePoolId].isPaired) revert BAKCNotOwnedOrPaired();

                mainToBakc[mainTypePoolId][pair.mainTokenId] = PairingStatus(pair.bakcTokenId, true);
                bakcToMain[pair.bakcTokenId][mainTypePoolId] = PairingStatus(pair.mainTokenId, true);
            } else if (pair.mainTokenId != bakcToMain[pair.bakcTokenId][mainTypePoolId].tokenId
                || pair.bakcTokenId != mainToBakc[mainTypePoolId][pair.mainTokenId].tokenId)
                revert BAKCAlreadyPaired();

            _depositNftGuard(BAKC_POOL_ID, position, pair.amount);
            totalDeposit += pair.amount;
            emit DepositPairNft(msg.sender, pair.amount, mainTypePoolId, pair.mainTokenId, pair.bakcTokenId);
            unchecked {
                ++i;
            }
        }
        if (totalDeposit > 0) apeCoin.transferFrom(msg.sender, address(this), totalDeposit);
    }

    function _depositNftGuard(uint256 _poolId, Position storage _position, uint256 _amount) private {
        if (_amount < MIN_DEPOSIT) revert DepositMoreThanOneAPE();
        if (_amount + _position.stakedAmount > pools[_poolId].timeRanges[pools[_poolId].lastRewardsRangeIndex].capPerPosition)
            revert ExceededCapAmount();

        _deposit(_poolId, _position, _amount);
    }

    function _claim(uint256 _poolId, Position storage _position, address _recipient) private returns (uint256 rewardsToBeClaimed) {
        Pool storage pool = pools[_poolId];

        int256 accumulatedApeCoins = (_position.stakedAmount * uint256(pool.accumulatedRewardsPerShare)).toInt256();
        rewardsToBeClaimed = (accumulatedApeCoins - _position.rewardsDebt).toUint256() / APE_COIN_PRECISION;

        _position.rewardsDebt = accumulatedApeCoins;

        if (rewardsToBeClaimed != 0) {
            apeCoin.transfer(_recipient, rewardsToBeClaimed);
        }
    }

    function _claimNft(uint256 _poolId, uint256[] calldata _nfts, address _recipient) private {
        updatePool(_poolId);
        uint256 tokenId;
        uint256 rewardsToBeClaimed;
        uint256 length = _nfts.length;
        for(uint256 i; i < length;) {
            tokenId = _nfts[i];
            if (nftContracts[_poolId].ownerOf(tokenId) != msg.sender) revert CallerNotOwner();
            Position storage position = nftPosition[_poolId][tokenId];
            rewardsToBeClaimed = _claim(_poolId, position, _recipient);
            emit ClaimRewardsNft(msg.sender, _poolId, rewardsToBeClaimed, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function _claimPairNft(uint256 mainTypePoolId, PairNft[] calldata _pairs, address _recipient) private {
        uint256 length = _pairs.length;
        uint256 mainTokenId;
        uint256 bakcTokenId;
        Position storage position;
        PairingStatus storage mainToSecond;
        PairingStatus storage secondToMain;
        for(uint256 i; i < length;) {
            mainTokenId = _pairs[i].mainTokenId;
            if (nftContracts[mainTypePoolId].ownerOf(mainTokenId) != msg.sender) revert NotOwnerOfMain();

            bakcTokenId = _pairs[i].bakcTokenId;
            if (nftContracts[BAKC_POOL_ID].ownerOf(bakcTokenId) != msg.sender) revert NotOwnerOfBAKC();

            mainToSecond = mainToBakc[mainTypePoolId][mainTokenId];
            secondToMain = bakcToMain[bakcTokenId][mainTypePoolId];

            if (mainToSecond.tokenId != bakcTokenId || !mainToSecond.isPaired
            || secondToMain.tokenId != mainTokenId || !secondToMain.isPaired) revert ProvidedTokensNotPaired();

            position = nftPosition[BAKC_POOL_ID][bakcTokenId];
            uint256 rewardsToBeClaimed = _claim(BAKC_POOL_ID, position, _recipient);
            emit ClaimRewardsPairNft(msg.sender, rewardsToBeClaimed, mainTypePoolId, mainTokenId, bakcTokenId);
            unchecked {
                ++i;
            }
        }
    }

    function _withdraw(uint256 _poolId, Position storage _position, uint256 _amount) private {
        if (_amount > _position.stakedAmount) revert ExceededStakedAmount();

        Pool storage pool = pools[_poolId];

        _position.stakedAmount -= _amount;
        pool.stakedAmount -= _amount.toUint96();
        _position.rewardsDebt -= (_amount * pool.accumulatedRewardsPerShare).toInt256();
    }

    function _withdrawNft(uint256 _poolId, SingleNft[] calldata _nfts, address _recipient) private {
        updatePool(_poolId);
        uint256 tokenId;
        uint256 amount;
        uint256 length = _nfts.length;
        uint256 totalWithdraw;
        Position storage position;
        for(uint256 i; i < length;) {
            tokenId = _nfts[i].tokenId;
            if (nftContracts[_poolId].ownerOf(tokenId) != msg.sender) revert CallerNotOwner();

            amount = _nfts[i].amount;
            position = nftPosition[_poolId][tokenId];
            if (amount == position.stakedAmount) {
                uint256 rewardsToBeClaimed = _claim(_poolId, position, _recipient);
                emit ClaimRewardsNft(msg.sender, _poolId, rewardsToBeClaimed, tokenId);
            }
            _withdraw(_poolId, position, amount);
            totalWithdraw += amount;
            emit WithdrawNft(msg.sender, _poolId, amount, _recipient, tokenId);
            unchecked {
                ++i;
            }
        }
        if (totalWithdraw > 0) apeCoin.transfer(_recipient, totalWithdraw);
    }

    function _withdrawPairNft(uint256 mainTypePoolId, PairNftWithdrawWithAmount[] calldata _nfts) private {
        address mainTokenOwner;
        address bakcOwner;
        PairNftWithdrawWithAmount memory pair;
        PairingStatus storage mainToSecond;
        PairingStatus storage secondToMain;
        Position storage position;
        uint256 length = _nfts.length;
        for(uint256 i; i < length;) {
            pair = _nfts[i];
            mainTokenOwner = nftContracts[mainTypePoolId].ownerOf(pair.mainTokenId);
            bakcOwner = nftContracts[BAKC_POOL_ID].ownerOf(pair.bakcTokenId);

            if (mainTokenOwner != msg.sender) {
                if (bakcOwner != msg.sender) revert NeitherTokenInPairOwnedByCaller();
            }

            mainToSecond = mainToBakc[mainTypePoolId][pair.mainTokenId];
            secondToMain = bakcToMain[pair.bakcTokenId][mainTypePoolId];

            if (mainToSecond.tokenId != pair.bakcTokenId || !mainToSecond.isPaired
            || secondToMain.tokenId != pair.mainTokenId || !secondToMain.isPaired) revert ProvidedTokensNotPaired();

            position = nftPosition[BAKC_POOL_ID][pair.bakcTokenId];
            if(!pair.isUncommit) {
                if(pair.amount == position.stakedAmount) revert UncommitWrongParameters();
            }
            if (mainTokenOwner != bakcOwner) {
                if (!pair.isUncommit) revert SplitPairCantPartiallyWithdraw();
            }

            if (pair.isUncommit) {
                uint256 rewardsToBeClaimed = _claim(BAKC_POOL_ID, position, bakcOwner);
                mainToBakc[mainTypePoolId][pair.mainTokenId] = PairingStatus(0, false);
                bakcToMain[pair.bakcTokenId][mainTypePoolId] = PairingStatus(0, false);
                emit ClaimRewardsPairNft(msg.sender, rewardsToBeClaimed, mainTypePoolId, pair.mainTokenId, pair.bakcTokenId);
            }
            uint256 finalAmountToWithdraw = pair.isUncommit ? position.stakedAmount: pair.amount;
            _withdraw(BAKC_POOL_ID, position, finalAmountToWithdraw);
            apeCoin.transfer(mainTokenOwner, finalAmountToWithdraw);
            emit WithdrawPairNft(msg.sender, finalAmountToWithdraw, mainTypePoolId, pair.mainTokenId, pair.bakcTokenId);
            unchecked {
                ++i;
            }
        }
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../contracts/Address.sol";

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
            (isTopLevelCall && _initialized < 1) ||
                (!Address.isContract(address(this)) && _initialized == 1),
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
        require(
            !_initializing && _initialized < version,
            "Initializable: contract is already initialized"
        );
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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "./Initializable.sol";

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
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "./ContextUpgradeable.sol";
import "./Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeCast.sol)
pragma solidity 0.8.10;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(
            value <= type(uint224).max,
            "SafeCast: value doesn't fit in 224 bits"
        );
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(
            value <= type(uint128).max,
            "SafeCast: value doesn't fit in 128 bits"
        );
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(
            value <= type(uint96).max,
            "SafeCast: value doesn't fit in 96 bits"
        );
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(
            value <= type(uint64).max,
            "SafeCast: value doesn't fit in 64 bits"
        );
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(
            value <= type(uint32).max,
            "SafeCast: value doesn't fit in 32 bits"
        );
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(
            value <= type(uint16).max,
            "SafeCast: value doesn't fit in 16 bits"
        );
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(
            value <= type(uint8).max,
            "SafeCast: value doesn't fit in 8 bits"
        );
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(
            value >= type(int128).min && value <= type(int128).max,
            "SafeCast: value doesn't fit in 128 bits"
        );
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(
            value >= type(int64).min && value <= type(int64).max,
            "SafeCast: value doesn't fit in 64 bits"
        );
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(
            value >= type(int32).min && value <= type(int32).max,
            "SafeCast: value doesn't fit in 32 bits"
        );
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(
            value >= type(int16).min && value <= type(int16).max,
            "SafeCast: value doesn't fit in 16 bits"
        );
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(
            value >= type(int8).min && value <= type(int8).max,
            "SafeCast: value doesn't fit in 8 bits"
        );
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(
            value <= uint256(type(int256).max),
            "SafeCast: value doesn't fit in an int256"
        );
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.10;

import "./IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

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
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity 0.8.10;

import "./IERC20.sol";
import "./draft-IERC20Permit.sol";
import "./Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
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
        IERC20 token,
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
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
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
        IERC20Permit token,
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/**
 * @title PercentageMath library
 *
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 **/
library PercentageMath {
    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    // Half percentage factor (50.00%)
    uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

    /**
     * @notice Executes a percentage multiplication
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param value The value of which the percentage needs to be calculated
     * @param percentage The percentage of the value to be calculated
     * @return result value percentmul percentage
     **/
    function percentMul(uint256 value, uint256 percentage)
        internal
        pure
        returns (uint256 result)
    {
        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        assembly {
            if iszero(
                or(
                    iszero(percentage),
                    iszero(
                        gt(
                            value,
                            div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)
                        )
                    )
                )
            ) {
                revert(0, 0)
            }

            result := div(
                add(mul(value, percentage), HALF_PERCENTAGE_FACTOR),
                PERCENTAGE_FACTOR
            )
        }
    }

    /**
     * @notice Executes a percentage division
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param value The value of which the percentage needs to be calculated
     * @param percentage The percentage of the value to be calculated
     * @return result value percentdiv percentage
     **/
    function percentDiv(uint256 value, uint256 percentage)
        internal
        pure
        returns (uint256 result)
    {
        // to avoid overflow, value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR
        assembly {
            if or(
                iszero(percentage),
                iszero(
                    iszero(
                        gt(
                            value,
                            div(
                                sub(not(0), div(percentage, 2)),
                                PERCENTAGE_FACTOR
                            )
                        )
                    )
                )
            ) {
                revert(0, 0)
            }

            result := div(
                add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)),
                percentage
            )
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from "../../../openzeppelin/contracts/Address.sol";
import {IERC1271} from "../../../openzeppelin/contracts/IERC1271.sol";

/**
 * @title SignatureChecker
 * @notice This library allows verification of signatures for both EOAs and contracts.
 */
library SignatureChecker {
    /**
     * @notice Recovers the signer of a signature (for EOA)
     * @param hash the hash containing the signed mesage
     * @param v parameter (27 or 28). This prevents maleability since the public key recovery equation has two possible solutions.
     * @param r parameter
     * @param s parameter
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        // https://ethereum.stackexchange.com/questions/83174/is-it-best-practice-to-check-signature-malleability-in-ecrecover
        // https://crypto.iacr.org/2019/affevents/wac/medias/Heninger-BiasedNonceSense.pdf
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "Signature: Invalid s parameter"
        );

        require(v == 27 || v == 28, "Signature: Invalid v parameter");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "Signature: Invalid signer");

        return signer;
    }

    /**
     * @notice Returns whether the signer matches the signed message
     * @param hash the hash containing the signed mesage
     * @param signer the signer address to confirm message validity
     * @param v parameter (27 or 28)
     * @param r parameter
     * @param s parameter
     * @param domainSeparator paramer to prevent signature being executed in other chains and environments
     * @return true --> if valid // false --> if invalid
     */
    function verify(
        bytes32 hash,
        address signer,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 domainSeparator
    ) internal view returns (bool) {
        // \x19\x01 is the standardized encoding prefix
        // https://eips.ethereum.org/EIPS/eip-712#specification
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, hash));
        if (Address.isContract(signer)) {
            // 0x1626ba7e is the interfaceId for signature contracts (see IERC1271)
            return IERC1271(signer).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e;
        } else {
            return recover(digest, v, r, s) == signer;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.10;

import "./ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < ERC721.balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < ERC721Enumerable.totalSupply(),
            "ERC721Enumerable: global index out of bounds"
        );
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        private
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Context.sol";

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
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity 0.8.10;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.10;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/ERC721.sol)

pragma solidity 0.8.10;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./Address.sol";
import "./Context.sol";
import "./Strings.sol";
import "./ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            owner != address(0),
            "ERC721: address zero is not a valid owner"
        );
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address owner = _owners[tokenId];
        require(
            owner != address(0),
            "ERC721: owner query for nonexistent token"
        );
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        require(
            _exists(tokenId),
            "ERC721: approved query for nonexistent token"
        );

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        require(
            _exists(tokenId),
            "ERC721: operator query for nonexistent token"
        );
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(
            ERC721.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.10;

import "./IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity 0.8.10;

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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.10;

import "./IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

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
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
 * @dev String operations.
 */
library Strings {
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
    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
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

pragma solidity 0.8.10;

import "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "./Initializable.sol";

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
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity 0.8.10;

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