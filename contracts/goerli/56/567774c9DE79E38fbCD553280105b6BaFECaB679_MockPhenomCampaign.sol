// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.13;

import "./PhenomCampaign.sol";
import "./MockTokenVesting.sol";

/**
 * @title MockPhenomCampaign
 * WARNING: use only for testing and debugging purpose
 */
contract MockPhenomCampaign is PhenomCampaign {

    MockTokenVesting public seedRoundVestingController_;
    MockTokenVesting public privateRoundVestingController_;
    MockTokenVesting public communitySaleVestingController_;
//    MockTokenVesting public communitySale1VestingController_;
//    MockTokenVesting public communitySale2VestingController_;
//    MockTokenVesting public communitySale3VestingController_;

    MockTokenVesting public fundingTeamVestingController_;
    MockTokenVesting public advisorsVestingController_;
    MockTokenVesting public marketingVestingController_;
    MockTokenVesting public developmentVestingController_;

    constructor(
        address _token,
        address _busdAddress,
        address payable _seedRoundVestingController,
        address payable _privateRoundVestingController,
        address payable _communitySaleVestingController,
//        address payable _communitySale1VestingController,
//        address payable _communitySale2VestingController,
//        address payable _communitySale3VestingController,

        address payable _fundingTeamVestingController,
        address payable _advisorsVestingController,
        address payable _marketingVestingController,
        address payable _developmentVestingController
    ) PhenomCampaign (
        _token,
        _busdAddress,
        _seedRoundVestingController,
        _privateRoundVestingController,
        _communitySaleVestingController,
//        _communitySale1VestingController,
//        _communitySale2VestingController,
//        _communitySale3VestingController,

        _fundingTeamVestingController,
        _advisorsVestingController,
        _marketingVestingController,
        _developmentVestingController
    ) {
        seedRoundVestingController_ = MockTokenVesting(_seedRoundVestingController);
        privateRoundVestingController_ = MockTokenVesting(_privateRoundVestingController);
        communitySaleVestingController_ = MockTokenVesting(_communitySaleVestingController);
//        communitySale1VestingController_ = MockTokenVesting(_communitySale1VestingController);
//        communitySale2VestingController_ = MockTokenVesting(_communitySale2VestingController);
//        communitySale3VestingController_ = MockTokenVesting(_communitySale3VestingController);

        fundingTeamVestingController_ = MockTokenVesting(_fundingTeamVestingController);
        advisorsVestingController_ = MockTokenVesting(_advisorsVestingController);
        marketingVestingController_ = MockTokenVesting(_marketingVestingController);
        developmentVestingController_ = MockTokenVesting(_developmentVestingController);
    }

    function _getVestingController(Phase _phase) internal virtual override view returns(TokenVesting) {
        if      (_phase == Phase.SEED)              { return seedRoundVestingController_; }
        else if (_phase == Phase.PRIVATE)           { return privateRoundVestingController_; }
        else if (_phase == Phase.COMMUNITY_SALE)  { return communitySaleVestingController_; }
//        else if (_phase == Phase.COMMUNITY_SALE_1)  { return communitySale1VestingController_; }
//        else if (_phase == Phase.COMMUNITY_SALE_2)  { return communitySale2VestingController_; }
//        else if (_phase == Phase.COMMUNITY_SALE_3)  { return communitySale3VestingController_; }

        else if (_phase == Phase.FUNDING_TEAM)      { return fundingTeamVestingController_; }
        else if (_phase == Phase.ADVISORS)          { return advisorsVestingController_; }
        else if (_phase == Phase.MARKETING)         { return marketingVestingController_; }
        else if (_phase == Phase.DEVELOPMENT)       { return developmentVestingController_; }
        else {
            revert("No vesting controller for phase");
        }
    }

    function setCurrentTime(uint256 _time) external {
        seedRoundVestingController_.setCurrentTime(_time);
        privateRoundVestingController_.setCurrentTime(_time);
        communitySaleVestingController_.setCurrentTime(_time);
//        communitySale1VestingController_.setCurrentTime(_time);
//        communitySale2VestingController_.setCurrentTime(_time);
//        communitySale3VestingController_.setCurrentTime(_time);

        fundingTeamVestingController_.setCurrentTime(_time);
        advisorsVestingController_.setCurrentTime(_time);
        marketingVestingController_.setCurrentTime(_time);
        developmentVestingController_.setCurrentTime(_time);
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./TokenVesting.sol";


/**
 * @title PhenomCampaign
 */
contract PhenomCampaign is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum Phase {
        SEED, // first
        PRIVATE,
        COMMUNITY_SALE,
//        COMMUNITY_SALE_1,
//        COMMUNITY_SALE_2,
//        COMMUNITY_SALE_3,

        FUNDING_TEAM,
        ADVISORS,
        MARKETING,
        DEVELOPMENT,
        PUBLIC // should be last!!
    }

    uint256 private constant MONTH_PERIOD = 30 days;
    uint256 public constant CAMPAIGN_DURATION = 48 * MONTH_PERIOD;

    uint256 public vestingStartTime;

    IERC20 immutable public token;
    IERC20 immutable public busd;

    TokenVesting public seedRoundVestingController;
    TokenVesting public privateRoundVestingController;
    TokenVesting public communitySaleVestingController;
//    TokenVesting public communitySale1VestingController;
//    TokenVesting public communitySale2VestingController;
//    TokenVesting public communitySale3VestingController;

    TokenVesting public fundingTeamVestingController;
    TokenVesting public advisorsVestingController;
    TokenVesting public marketingVestingController;
    TokenVesting public developmentVestingController;

    struct PublicSale {
        address buyer;
        uint256 busdAmount;
        uint256 phetaAmount;
        uint256 date;
    }

    PublicSale[] public publicSaleRegistry;
    uint256 public publicSaleRegistryCount;

    struct PreTgePurchase {
        Phase phase;
        address buyer;
        uint256 phetaAmount;
    }

    PreTgePurchase[] public preTgePurchases;
    uint256 public preTgePurchasesCount;
    mapping(Phase => uint256) public preTgePurchaseTotals;

    mapping(Phase => uint256) public priceByPhase; // should be divided by 1000

    event PriceUpdated(Phase indexed phase, uint256 indexed oldPrice, uint256 indexed newPrive);
    event PurchaseRegistered(Phase indexed phase, address indexed investor, uint256 amount);
    event VestingStartTimeUpdated(uint256 vestingStartTime);
    event BalanceApproved(address indexed investor, string token, uint256 balance);
    event PublicPurchase(address indexed buyer, uint256 busdAmount, uint256 phetaAmount);
    event Released(Phase indexed phase, address indexed investor);
    event Withdraw(Phase indexed phase, uint256 amount);

    constructor(
        address _token,
        address _busdAddress,
        address payable _seedRoundVestingController,
        address payable _privateRoundVestingController,
        address payable _communitySaleVestingController,
//        address payable _communitySale1VestingController,
//        address payable _communitySale2VestingController,
//        address payable _communitySale3VestingController,

        address payable _fundingTeamVestingController,
        address payable _advisorsVestingController,
        address payable _marketingVestingController,
        address payable _developmentVestingController
    ) {

        require(_token != address(0x0));
        require(_busdAddress != address(0x0));
//        require(_tgeTime > block.timestamp, "TGE should be in future");

        token = IERC20(_token);
        busd = IERC20(_busdAddress);
//        vestingStartTime = _tgeTime;

        priceByPhase[Phase.SEED] = 35; // 0,035
        priceByPhase[Phase.PRIVATE] = 40; // 0,04
        priceByPhase[Phase.COMMUNITY_SALE] = 50; // 0,05
//        priceByPhase[Phase.COMMUNITY_SALE_1] = 50; // 0,05
//        priceByPhase[Phase.COMMUNITY_SALE_2] = 80; // 0,08
//        priceByPhase[Phase.COMMUNITY_SALE_3] = 100; // 0,1
        priceByPhase[Phase.PUBLIC] = 110; // 0,11
        //...

        seedRoundVestingController = TokenVesting(_seedRoundVestingController);
        privateRoundVestingController = TokenVesting(_privateRoundVestingController);
        communitySaleVestingController = TokenVesting(_communitySaleVestingController);
//        communitySale1VestingController = TokenVesting(_communitySale1VestingController);
//        communitySale2VestingController = TokenVesting(_communitySale2VestingController);
//        communitySale3VestingController = TokenVesting(_communitySale3VestingController);

        fundingTeamVestingController = TokenVesting(_fundingTeamVestingController);
        advisorsVestingController = TokenVesting(_advisorsVestingController);
        marketingVestingController = TokenVesting(_marketingVestingController);
        developmentVestingController = TokenVesting(_developmentVestingController);
    }

    function setVestingStartTime(uint256 _time) external onlyOwner {
        require(vestingStartTime == 0, "Vesting start time already settled");
        require(_time > block.timestamp, "Vesting start should be in future");

        vestingStartTime = _time;

        emit VestingStartTimeUpdated(vestingStartTime);
    }

    function startVestingForLast200PreTgePurchases() external onlyOwner {
        require(vestingStartTime > 0, "Vesting start time should be settled");
        require(preTgePurchasesCount > 0, "No pre TGE purchases");

        for (uint i = 1; i < 200 && preTgePurchasesCount > 0; i++) {
            PreTgePurchase memory _purchase = preTgePurchases[preTgePurchasesCount - 1];
            preTgePurchases.pop();
            preTgePurchasesCount--;
            registerPurchaseInternal(_purchase.phase, _purchase.buyer, _purchase.phetaAmount);
        }
    }

    // _usdAmount in cents (multiplied to 100)
    function registerUsdPurchase(Phase _phase, address _investor, uint256 _usdAmount) public onlyOwner {
        require(_investor != address(0x0), "Invalid beneficiary address");
        require(_usdAmount > 0, "Invalid USD amount");

        uint256 _price = priceByPhase[_phase]; // should be divided by 1000
        require(_price > 0, "Invalid price");

        uint256 _tokenAmount = _price.mul(_usdAmount).mul(1 ether).div(100).div(1000);

        registerPurchaseInternal(_phase, _investor, _tokenAmount);
    }

    // _usdAmounts in cents (multiplied to 100)
    function registerMultiplyUsdPurchases(Phase _phase, address[] calldata _investors, uint256[] calldata _usdAmounts) external onlyOwner {
        require(_investors.length == _usdAmounts.length, "Investors list and usdAmounts list should be same size");

        for(uint i = 0; i < _investors.length; i++) {
            registerUsdPurchase(_phase, _investors[i], _usdAmounts[i]);
        }
    }

    // Register purchase of Pheta tokens by owner
    function registerPurchase(Phase _phase, address _investor, uint256 _amount) external onlyOwner {
        registerPurchaseInternal(_phase, _investor, _amount);
    }

    function registerPurchaseInternal(Phase _phase, address _investor, uint256 _amount) private {
        require(_investor != address(0x0), "Invalid beneficiary address");
        require(_amount > 0, "Invalid amount");
        require(_phase != Phase.PUBLIC, "Vesting is not allowed on public round");

        TokenVesting _vestingController = _getVestingController(_phase);

        if (vestingStartTime == 0) {
            // before TGE
            require(token.balanceOf(address(_vestingController)) - preTgePurchaseTotals[_phase] >= _amount, "Insufficient supply amount");
//            require(preTgePurchasesCount < 200, "Maximum of pre TGE purchases (200) exceeded");

            preTgePurchases.push(PreTgePurchase(
                _phase,
                _investor,
                _amount
            ));
            preTgePurchasesCount++;
            preTgePurchaseTotals[_phase] = preTgePurchaseTotals[_phase] + _amount;
        } else {
            require(token.balanceOf(address(_vestingController)) >= _amount, "Insufficient supply amount");

            if (_phase == Phase.SEED || _phase == Phase.PRIVATE) {
                // immediate unlock of 5%
                _vestingController.createVestingSchedule(
                    _investor,
                    vestingStartTime,
                    0, // no cliff
                    1 seconds, // duration
                    1 seconds, // daily
                    true, // revocable
                    _amount.div(20)
                );
                // linear vesting without lock-up period
                _vestingController.createVestingSchedule(
                    _investor,
                    vestingStartTime,
                    0, // no cliff
                    19 * MONTH_PERIOD, // duration
                    1 days, // daily
                    true, // revocable
                    _amount.sub(_amount.div(20))
                );
            }

            else if (_phase == Phase.COMMUNITY_SALE) {
                // linear vesting without lock-up period
                _vestingController.createVestingSchedule(
                    _investor,
                    vestingStartTime,
                    0, // no cliff
                    20 * MONTH_PERIOD, // duration
                    1 days, // daily
                    true, // revocable
                    _amount
                );
            }

            else if (_phase == Phase.FUNDING_TEAM) {
                // 3 months lock-up and 24 leaner monthly vesting
                _vestingController.createVestingSchedule(
                    _investor,
                    vestingStartTime.add(3 * MONTH_PERIOD), // skip first 3 month
                    0, // no cliff
                    24 * MONTH_PERIOD, // 24 month duration
                    1 days, // daily
                    true, // revocable
                    _amount
                );
            }

            else if (_phase == Phase.ADVISORS) {
                // Daily unlock for 360 days, starting 120 days from TGE
                _vestingController.createVestingSchedule(
                    _investor,
                    vestingStartTime.add(4 * MONTH_PERIOD), // skip first 4 months
                    0, // no cliff
                    12 * MONTH_PERIOD, // 1 year duration
                    1 days, // daily unlock
                    true,
                    _amount
                );
            }

            else if (_phase == Phase.MARKETING || _phase == Phase.DEVELOPMENT) {
                // 6 months lock-up and 18 leaner monthly vesting
                _vestingController.createVestingSchedule(
                    _investor,
                    vestingStartTime.add(6 * MONTH_PERIOD), // skip first 6 month
                    0, // no cliff
                    18 * MONTH_PERIOD, // 18 month duration
                    1 days, // daily
                    true, // revocable
                    _amount
                );
            }

            else {
                revert("Undefined Phase");
            }
        }

        emit PurchaseRegistered(_phase, _investor, _amount);
    }

    function registerMultiplyPurchases(Phase _phase, address[] calldata _investors, uint256[] calldata _amounts) external onlyOwner {
        require(_investors.length == _amounts.length, "Investors list and amounts list should be same size");

        for(uint i = 0; i < _investors.length; i++) {
            registerPurchaseInternal(_phase, _investors[i], _amounts[i]);
        }
    }

    function _getVestingController(Phase _phase) internal virtual view returns(TokenVesting) {
        if      (_phase == Phase.SEED)              { return seedRoundVestingController; }
        else if (_phase == Phase.PRIVATE)           { return privateRoundVestingController; }
        else if (_phase == Phase.COMMUNITY_SALE)    { return communitySaleVestingController; }
//        else if (_phase == Phase.COMMUNITY_SALE_1)  { return communitySale1VestingController; }
//        else if (_phase == Phase.COMMUNITY_SALE_2)  { return communitySale2VestingController; }
//        else if (_phase == Phase.COMMUNITY_SALE_3)  { return communitySale3VestingController; }

        else if (_phase == Phase.FUNDING_TEAM)      { return fundingTeamVestingController; }
        else if (_phase == Phase.ADVISORS)          { return advisorsVestingController; }
        else if (_phase == Phase.MARKETING)         { return marketingVestingController; }
        else if (_phase == Phase.DEVELOPMENT)       { return developmentVestingController; }
        else {
            revert("No vesting controller for phase");
        }
    }

    function getAvailableAmount() public view returns(uint256) {
        return getAvailableAmountByInvestor(_msgSender());
    }

    function getInvestedAmount() external view returns(uint256) {
        return getInvestedAmountByInvestor(_msgSender());
    }

    function getReleasedAmount() public view returns(uint256) {
        return getReleasedAmountByInvestor(_msgSender());
    }

    function getAvailableAmountByInvestor(address _investor) public view returns(uint256) {
        uint256 _amount;
        for(uint _phaseIndex = uint(Phase.SEED); _phaseIndex < uint(Phase.PUBLIC); _phaseIndex++) {
            _amount = _amount.add(getAvailableAmountByPhaseAndInvestor(Phase(_phaseIndex), _investor));
        }
        return _amount;
    }

    function getInvestedAmountByInvestor(address _investor) public view returns(uint256) {
        uint256 _amount;
        for(uint _phaseIndex = uint(Phase.SEED); _phaseIndex < uint(Phase.PUBLIC); _phaseIndex++) {
            _amount = _amount.add(getInvestedAmountByPhaseAndInvestor(Phase(_phaseIndex), _investor));
        }
        return _amount;
    }

    function getAvailableAmountByPhaseAndInvestor(Phase _phase, address _investor) public view returns(uint256) {
        TokenVesting _vestingController = _getVestingController(_phase);

        uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCountByBeneficiary(_investor);
        uint256 _amount;
        for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
            bytes32 _vestingScheduleId = _vestingController.computeVestingScheduleIdForAddressAndIndex(_investor, i);
            _amount = _amount.add(_vestingController.computeReleasableAmount(_vestingScheduleId));
        }
        return _amount;
    }

    function getAvailableAmountByPhase(Phase _phase) public view returns(uint256) {
        TokenVesting _vestingController = _getVestingController(_phase);

        uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCount();
        uint256 _amount;
        for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
            bytes32 _vestingScheduleId = _vestingController.getVestingIdAtIndex(i);
            _amount = _amount.add(_vestingController.computeReleasableAmount(_vestingScheduleId));
        }
        return _amount;
    }

    function getInvestedAmountByPhase(Phase _phase) public view returns(uint256) {
        if (vestingStartTime > 0) {
            TokenVesting _vestingController = _getVestingController(_phase);

            uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCount();
            uint256 _amount;
            for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
                bytes32 _vestingScheduleId = _vestingController.getVestingIdAtIndex(i);
                _amount = _amount.add(_vestingController.getVestingSchedule(_vestingScheduleId).amountTotal);
            }
            return _amount;
        } else {
            return preTgePurchaseTotals[_phase];
        }
    }

    function getReleasedAmountByPhase(Phase _phase) public view returns(uint256) {
        TokenVesting _vestingController = _getVestingController(_phase);

        uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCount();
        uint256 _amount;
        for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
            bytes32 _vestingScheduleId = _vestingController.getVestingIdAtIndex(i);
            _amount = _amount.add(_vestingController.getVestingSchedule(_vestingScheduleId).released);
        }
        return _amount;
    }

    function getReleasedAmountByInvestor(address _investor) public view returns(uint256) {
        uint256 _amount;
        for(uint _phaseIndex = uint(Phase.SEED); _phaseIndex < uint(Phase.PUBLIC); _phaseIndex++) {
            _amount = _amount.add(getReleasedAmountByPhaseAndInvestor(Phase(_phaseIndex), _investor));
        }
        return _amount;
    }

    function getReleasedAmountByPhaseAndInvestor(Phase _phase, address _investor) public view returns(uint256) {
        TokenVesting _vestingController = _getVestingController(_phase);

        uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCountByBeneficiary(_investor);
        uint256 _amount;
        for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
            bytes32 _vestingScheduleId = _vestingController.computeVestingScheduleIdForAddressAndIndex(_investor, i);
            _amount = _amount.add(_vestingController.getVestingSchedule(_vestingScheduleId).released);
        }
        return _amount;
    }

    function getInvestedAmountByPhaseAndInvestor(Phase _phase, address _investor) public view returns(uint256) {
        if (vestingStartTime > 0) {
            TokenVesting _vestingController = _getVestingController(_phase);

            uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCountByBeneficiary(_investor);
            uint256 _amount;
            for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
                bytes32 _vestingScheduleId = _vestingController.computeVestingScheduleIdForAddressAndIndex(_investor, i);
                _amount = _amount.add(_vestingController.getVestingSchedule(_vestingScheduleId).amountTotal);
            }
            return _amount;
        } else {
            uint256 _amount;
            for (uint256 i = 0; i < preTgePurchases.length; i++) {
                PreTgePurchase memory _purchase = preTgePurchases[i];
                if (_purchase.phase == _phase && _purchase.buyer == _investor) {
                    _amount = _amount.add(_purchase.phetaAmount);
                }
            }
            return _amount;
        }
    }

    function releaseAvailable() external {
        if(getAvailableAmount() > 0) {
            for(uint _phaseIndex = uint(Phase.SEED); _phaseIndex < uint(Phase.PUBLIC); _phaseIndex++) {
                releaseAvailableByPhaseAndInvestor(Phase(_phaseIndex), _msgSender());
            }
        }
    }

    function releaseAvailableByInvestor(address _investor) external onlyOwner {
        require(getAvailableAmountByInvestor(_investor) > 0, "Nothing to release");

        for(uint _phaseIndex = uint(Phase.SEED); _phaseIndex < uint(Phase.PUBLIC); _phaseIndex++) {
            releaseAvailableByPhaseAndInvestor(Phase(_phaseIndex), _investor);
        }
    }

    function releaseAvailableByPhaseAndInvestor(Phase _phase, address _investor) public {
        require(_investor == _msgSender() || _msgSender() == owner(), "Only investor or owner can release");
        require(_investor != address(0x0), "Invalid beneficiary address");

        TokenVesting _vestingController = _getVestingController(_phase);

        uint256 _vestingSchedulesCount = _vestingController.getVestingSchedulesCountByBeneficiary(_investor);

        uint256 _releaseCount = 0;
        uint256 _maximumReleaseCount = 50;

        for (uint256 i = 0; i < _vestingSchedulesCount; i++) {
            if (_releaseCount >= _maximumReleaseCount) {
                // gas overflow protection
                return;
            }
            bytes32 _vestingScheduleId = _vestingController.computeVestingScheduleIdForAddressAndIndex(_investor, i);
            uint256 _amount = _vestingController.computeReleasableAmount(_vestingScheduleId);
            if (_amount > 0) {
                _vestingController.release(_vestingScheduleId, _amount);
                _releaseCount++;
            }
        }

        emit Released(_phase, _investor);
    }

    function getWithdrawableAmountByPhase(Phase _phase) external view returns(uint256) {
        if (_phase == Phase.PUBLIC) {
            return token.balanceOf(address(this));
        } else {
            return _getVestingController(_phase).getWithdrawableAmount();
        }
    }

    function getSupplyByPhase(Phase _phase) public view returns(uint256) {
        if (_phase == Phase.PUBLIC) {
            return token.balanceOf(address(this));
        } else {
            return token.balanceOf(address(_getVestingController(_phase)));
        }
    }

    function withdraw(Phase _phase, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Invalid amount");

        if (_phase == Phase.PUBLIC) {
            token.transfer(owner(), _amount);
        } else {
            _getVestingController(_phase).withdraw(_amount);
            token.transfer(owner(), _amount);
        }

        emit Withdraw(_phase, _amount);
    }

    function updatePrice(Phase _phase, uint256 _price) external onlyOwner {
        require(_price > 0, "Invalid price");

        uint256 _oldPrice = priceByPhase[_phase];
        priceByPhase[_phase] = _price;

        emit PriceUpdated(_phase, _oldPrice, _price);
    }

    function buy(uint256 _busdAmount, uint256 _maxPrice) external {
        require(_busdAmount > 0, "Invalid BUSD amount");
        require(vestingStartTime > 0 && vestingStartTime < block.timestamp, "Public sale available after TGE");

        uint256 _allowedAmount = busd.allowance(_msgSender(), address(this));
        require(_allowedAmount >= _busdAmount, "Not enough allowed amount");

        uint256 _price = priceByPhase[Phase.PUBLIC]; // should be divided by 1000
        require(_price > 0, "Invalid price");
        require(_price <= _maxPrice, "Bad price");

        uint256 _phetaAmount = _busdAmount.mul(1000).div(_price);
        require(_phetaAmount > 0, "Invalid PHETA amount");

        busd.transferFrom(_msgSender(), owner(), _busdAmount);
        token.transfer(_msgSender(), _phetaAmount);

        publicSaleRegistry.push(PublicSale(_msgSender(), _busdAmount, _phetaAmount, block.timestamp));
        publicSaleRegistryCount ++;

        emit PublicPurchase(_msgSender(), _busdAmount, _phetaAmount);
    }

    function publicRoundActive() public view returns(bool) {
        return vestingStartTime > 0 && vestingStartTime < block.timestamp;
    }

    function revoke(Phase _phase, bytes32 _vestingScheduleId) external onlyOwner {
        require(_phase != Phase.PUBLIC, "Not available for public round");
        TokenVesting _vestingController = _getVestingController(_phase);
        _vestingController.revoke(_vestingScheduleId);
    }

    function amountPhetaSoldInPublicRound() public view returns(uint256) {
        uint256 _amount;
        for (uint256 i = 0; i < publicSaleRegistryCount; i++) {
            _amount = _amount.add(publicSaleRegistry[i].phetaAmount);
        }
        return _amount;
    }

    function amountUsdSoldInPublicRound() public view returns(uint256) {
        uint256 _amount;
        for (uint256 i = 0; i < publicSaleRegistryCount; i++) {
            _amount = _amount.add(publicSaleRegistry[i].busdAmount);
        }
        return _amount;
    }

    ////////////////


    mapping(bytes32 => uint256) private externalBalances;

    function setExternalBalances(uint256[] calldata _balances, bytes32[] calldata _hashes) external onlyOwner {
        require(_balances.length == _hashes.length, "Input arrays size should be the same");

        for (uint256 i = 0; i < _balances.length; i++) {
            externalBalances[_hashes[i]] = _balances[i];
        }
    }

    function getExternalBalance(string memory _token) public view returns(uint256) {
        return externalBalances[hash(_token)];
    }

    function approveExternalBalance(string memory _token) external {
        bytes32 _hash = hash(_token);

        uint256 _balance = externalBalances[_hash];

        require(_balance > 0, "No balance for given hash");

        delete externalBalances[_hash];
        registerPurchaseInternal(Phase.COMMUNITY_SALE, _msgSender(), _balance);

        emit BalanceApproved(_msgSender(), _token, _balance);
    }

    function hash(string memory _token) public pure returns(bytes32) {
        return keccak256(abi.encode(_token));
    }

    // we should not receive any ETH
//    receive() external payable {}

//    fallback() external payable {}
}

// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.13;

import "./TokenVesting.sol";

/**
 * @title MockTokenVesting
 * WARNING: use only for testing and debugging purpose
 */
contract MockTokenVesting is TokenVesting{

    uint256 mockTime = 0;

    constructor(address token_) TokenVesting(token_){
    }

    function setCurrentTime(uint256 _time)
        external{
        mockTime = _time;
    }

    function getCurrentTime()
        internal
        virtual
        override
        view
        returns(uint256){
        return mockTime;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

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
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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

pragma solidity ^0.8.0;

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

    constructor () {
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
    constructor () {
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

pragma solidity ^0.8.0;

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

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
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
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title TokenVesting

 CHANGES:
 removed receive and fallback methods to prevent receiving ETH. See https://github.com/crytic/slither/wiki/Detector-Documentation#contracts-that-lock-ether
 createVestingSchedule(), revoke(), withdraw(), computeReleasableAmount(), getLastVestingScheduleForHolder(): public -> external
 */
contract TokenVesting is Ownable, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule{
        bool initialized;
        // beneficiary of tokens after they are released
        address  beneficiary;
        // cliff period in seconds
        uint256  cliff;
        // start time of the vesting period
        uint256  start;
        // duration of the vesting period in seconds
        uint256  duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // whether or not the vesting is revocable
        bool  revocable;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256  released;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    // address of the ERC20 token
    IERC20 immutable private _token;

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;

    event Released(uint256 amount);
    event Revoked();

    /**
    * @dev Reverts if no vesting schedule matches the passed identifier.
    */
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        _;
    }

    /**
    * @dev Reverts if the vesting schedule does not exist or has been revoked.
    */
    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        require(vestingSchedules[vestingScheduleId].revoked == false);
        _;
    }

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    // we should not receive any ETH
//    receive() external payable {}

//    fallback() external payable {}

    /**
    * @dev Returns the number of vesting schedules associated to a beneficiary.
    * @return the number of vesting schedules
    */
    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
    external
    view
    returns(uint256){
        return holdersVestingCount[_beneficiary];
    }

    /**
    * @dev Returns the vesting schedule id at the given index.
    * @return the vesting id
    */
    function getVestingIdAtIndex(uint256 index)
    external
    view
    returns(bytes32){
        require(index < getVestingSchedulesCount(), "TokenVesting: index out of bounds");
        return vestingSchedulesIds[index];
    }

    /**
    * @notice Returns the vesting schedule information for a given holder and index.
    * @return the vesting schedule structure information
    */
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
    external
    view
    returns(VestingSchedule memory){
        return getVestingSchedule(computeVestingScheduleIdForAddressAndIndex(holder, index));
    }


    /**
    * @notice Returns the total amount of vesting schedules.
    * @return the total amount of vesting schedules
    */
    function getVestingSchedulesTotalAmount()
    external
    view
    returns(uint256){
        return vestingSchedulesTotalAmount;
    }

    /**
    * @dev Returns the address of the ERC20 token managed by the vesting contract.
    */
    function getToken()
    external
    view
    returns(address){
        return address(_token);
    }

    /**
    * @notice Creates a new vesting schedule for a beneficiary.
    * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
    * @param _start start time of the vesting period
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
    * @param _revocable whether the vesting is revocable or not
    * @param _amount total amount of tokens to be released at the end of the vesting
    */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    )
        external
        onlyOwner {
        require(
            this.getWithdrawableAmount() >= _amount,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amount > 0, "TokenVesting: amount must be > 0");
        require(_slicePeriodSeconds >= 1, "TokenVesting: slicePeriodSeconds must be >= 1");
        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(_beneficiary);
        uint256 cliff = _start.add(_cliff);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            0,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount.add(1);
    }

    /**
    * @notice Revokes the vesting schedule for given identifier.
    * @param vestingScheduleId the vesting schedule identifier
    */
    function revoke(bytes32 vestingScheduleId)
        external
        onlyOwner
        onlyIfVestingScheduleNotRevoked(vestingScheduleId){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        require(vestingSchedule.revocable == true, "TokenVesting: vesting is not revocable");
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if(vestedAmount > 0){
            release(vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal.sub(vestingSchedule.released);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(unreleased);
        vestingSchedule.revoked = true;
    }

    /**
    * @notice Withdraw the specified amount if possible.
    * @param amount the amount to withdraw
    */
    function withdraw(uint256 amount)
        external
        nonReentrant
        onlyOwner{
        require(this.getWithdrawableAmount() >= amount, "TokenVesting: not enough withdrawable funds");
        _token.safeTransfer(owner(), amount);
    }

    /**
    * @notice Release vested amount of tokens.
    * @param vestingScheduleId the vesting schedule identifier
    * @param amount the amount to release
    */
    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    )
        public
        nonReentrant
        onlyIfVestingScheduleNotRevoked(vestingScheduleId){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "TokenVesting: only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount >= amount, "TokenVesting: cannot release tokens, not enough vested tokens");
        vestingSchedule.released = vestingSchedule.released.add(amount);
        address payable beneficiaryPayable = payable(vestingSchedule.beneficiary);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(amount);
        _token.safeTransfer(beneficiaryPayable, amount);
    }

    /**
    * @dev Returns the number of vesting schedules managed by this contract.
    * @return the number of vesting schedules
    */
    function getVestingSchedulesCount()
        public
        view
        returns(uint256){
        return vestingSchedulesIds.length;
    }

    /**
    * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
    * @return the vested amount
    */
    function computeReleasableAmount(bytes32 vestingScheduleId)
        external
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        view
        returns(uint256){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
    * @notice Returns the vesting schedule information for a given identifier.
    * @return the vesting schedule structure information
    */
    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[vestingScheduleId];
    }

    /**
    * @dev Returns the amount of tokens that can be withdrawn by the owner.
    * @return the amount of tokens
    */
    function getWithdrawableAmount()
        public
        view
        returns(uint256){
        return _token.balanceOf(address(this)).sub(vestingSchedulesTotalAmount);
    }

    /**
    * @dev Computes the next vesting schedule identifier for a given holder address.
    */
    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns(bytes32){
        return computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder]);
    }

    /**
    * @dev Returns the last vesting schedule for a given holder address.
    */
    function getLastVestingScheduleForHolder(address holder)
        external
        view
        returns(VestingSchedule memory){
        return vestingSchedules[computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder] - 1)];
    }

    /**
    * @dev Computes the vesting schedule identifier for an address and an index.
    */
    function computeVestingScheduleIdForAddressAndIndex(address holder, uint256 index)
        public
        pure
        returns(bytes32){
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
    * @dev Computes the releasable amount of tokens for a vesting schedule.
    * @return the amount of releasable tokens
    */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        uint256 currentTime = getCurrentTime();
        if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked == true) {
            return 0;
        } else if (currentTime >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
            uint256 vestedAmount = vestingSchedule.amountTotal.mul(vestedSeconds).div(vestingSchedule.duration);
            vestedAmount = vestedAmount.sub(vestingSchedule.released);
            return vestedAmount;
        }
    }

    function getCurrentTime()
        internal
        virtual
        view
        returns(uint256){
        return block.timestamp;
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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

pragma solidity ^0.8.0;

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}