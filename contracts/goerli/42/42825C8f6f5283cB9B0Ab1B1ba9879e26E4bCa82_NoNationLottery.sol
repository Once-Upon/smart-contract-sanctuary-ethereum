// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/INoNationLottery.sol";
import "../interfaces/IRandomNumberGenerator.sol";
import "../interfaces/IWETH.sol";

/** @title NoNation Lottery
 * @notice It is a contract for a lottery system using
 * randomness provided externally.
 */
contract NoNationLottery is ReentrancyGuard, Ownable, Pausable, INoNationLottery {
    using SafeERC20 for IERC20;

    address public injectorAddress;
    address public operatorAddress;

    uint256 public currentLotteryId;
    uint256 public currentTicketId;

    uint256 public maxNumberTicketsPerBuyOrClaim = 100;

    uint256 public pendingInjectionNextLottery;

    uint256 public constant MIN_LENGTH_LOTTERY = 5 minutes; // Default is 4 hours, but temporary set to 5 minutes for testing purpose
    uint256 public constant MAX_LENGTH_LOTTERY = 7 days; // 7 days
    uint256 public constant MAX_ROLL_OVER_FEE = 3000; // 30%
    uint256 public constant BASE_DENOMINATOR = 10000; // 100%

    IERC20 public nona;
    address public weth;

    IRandomNumberGenerator public randomGenerator;

    enum Status {
        Pending,
        Open,
        Close,
        Claimable
    }

    struct Lottery {
        Status status;
        uint256 startTime;
        uint256 endTime;
        uint256 priceTicketInLotteryToken;
        uint256[6] rewardsBreakdown; // 0: 1 matching number // 5: 6 matching numbers
        uint256 rolloverFee; // 500: 5% // 200: 2% // 50: 0.5%
        uint256[6] wethPerBracket;
        uint256[6] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 firstTicketIdNextLottery;
        uint256 amountCollectedInLotteryToken;
        uint32 finalNumber;
    }

    struct Ticket {
        uint32 number;
        address owner;
    }

    // Mapping are cheaper than arrays
    mapping(uint256 => Lottery) private _lotteries;
    mapping(uint256 => Ticket) private _tickets;

    // Keeps track of number of user per lotteryId
    mapping(uint256 => uint256) private _playersPerLottery;

    // Bracket calculator is used for verifying claims for ticket prizes
    mapping(uint32 => uint32) private _bracketCalculator;

    // Keeps track of number of ticket per unique combination for each lotteryId
    mapping(uint256 => mapping(uint32 => uint256))
        private _numberTicketsPerLotteryId;

    // Keep track of user ticket ids for a given lotteryId
    mapping(address => mapping(uint256 => uint256[]))
        private _userTicketIdsPerLotteryId;

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier onlyOwnerOrInjector() {
        require(
            (msg.sender == owner()) || (msg.sender == injectorAddress),
            "Not owner or injector"
        );
        _;
    }

    event AdminTokenRecovery(address token, uint256 amount);
    event LotteryClose(
        uint256 indexed lotteryId,
        uint256 firstTicketIdNextLottery
    );
    event LotteryInjection(uint256 indexed lotteryId, uint256 injectedAmount);
    event LotteryOpen(
        uint256 indexed lotteryId,
        uint256 startTime,
        uint256 endTime,
        uint256 priceTicketInLotteryToken,
        uint256 firstTicketId,
        uint256 injectedAmount
    );
    event LotteryNumberDrawn(
        uint256 indexed lotteryId,
        uint256 finalNumber,
        uint256 countWinningTickets
    );
    event NewOperatorAndInjectorAddresses(address operator, address injector);
    event NewRandomGenerator(address indexed randomGenerator);
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );
    event TicketsClaim(
        address indexed claimer,
        uint256 amount,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );

    /**
     * @notice Constructor
     * @dev RandomNumberGenerator must be deployed prior to this contract
     * @param _nona: address of NONA token
     * @param _weth: address of WETH token
     * @param _randomGeneratorAddress: address of the RandomGenerator contract used to work with ChainLink VRF
     */
    constructor(address _nona, address _weth, address _randomGeneratorAddress) {
        nona = IERC20(_nona);
        weth = _weth; // Goerli WETH
        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);

        // Initializes a mapping
        _bracketCalculator[0] = 1;
        _bracketCalculator[1] = 11;
        _bracketCalculator[2] = 111;
        _bracketCalculator[3] = 1111;
        _bracketCalculator[4] = 11111;
        _bracketCalculator[5] = 111111;
    }

    /**
     * @notice Start the lottery
     * @dev Callable by operator
     * @param _endTime: endTime of the lottery
     * @param _priceTicketInLotteryToken: price of a ticket in nona
     * @param _rewardsBreakdown: breakdown of rewards per bracket (must sum to 10,000)
     * @param _rolloverFee: Rollover fee (10,000 = 100%, 100 = 1%)
     */
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicketInLotteryToken,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _rolloverFee
    ) external override onlyOperator {
        require(
            (currentLotteryId == 0) ||
                (_lotteries[currentLotteryId].status == Status.Claimable),
            "Not time to start lottery"
        );

        require(
            ((_endTime - block.timestamp) > MIN_LENGTH_LOTTERY) &&
                ((_endTime - block.timestamp) < MAX_LENGTH_LOTTERY),
            "Lottery length outside of range"
        );

        require(_rolloverFee <= MAX_ROLL_OVER_FEE, "Roll over fee too high");

        require(
            (_rewardsBreakdown[0] +
                _rewardsBreakdown[1] +
                _rewardsBreakdown[2] +
                _rewardsBreakdown[3] +
                _rewardsBreakdown[4] +
                _rewardsBreakdown[5]) == BASE_DENOMINATOR,
            "Rewards must equal 10,000"
        );

        currentLotteryId++;

        _lotteries[currentLotteryId] = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTime: _endTime,
            priceTicketInLotteryToken: _priceTicketInLotteryToken,
            rewardsBreakdown: _rewardsBreakdown,
            rolloverFee: _rolloverFee,
            wethPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            countWinnersPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            firstTicketId: currentTicketId,
            firstTicketIdNextLottery: currentTicketId,
            amountCollectedInLotteryToken: pendingInjectionNextLottery,
            finalNumber: 0
        });

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _endTime,
            _priceTicketInLotteryToken,
            currentTicketId,
            pendingInjectionNextLottery
        );

        pendingInjectionNextLottery = 0;
    }

    /**
     * @notice Buy tickets for the current lottery
     * @param _lotteryId: lotteryId
     * @param _ticketNumbers: array of ticket numbers between 1,000,000 and 1,999,999
     * @dev Callable by users
     */
    function buyTickets(uint256 _lotteryId, uint32[] calldata _ticketNumbers)
        external
        override
        notContract
        nonReentrant
        whenNotPaused
    {
        require(_ticketNumbers.length != 0, "No ticket specified");
        require(
            _ticketNumbers.length <= maxNumberTicketsPerBuyOrClaim,
            "Too many tickets"
        );

        require(
            _lotteries[_lotteryId].status == Status.Open,
            "Lottery is not open"
        );
        require(
            block.timestamp < _lotteries[_lotteryId].endTime,
            "Lottery is over"
        );

        // Calculate number of nona to this contract
        uint256 amountLotteryTokenToTransfer = _calculateTotalPriceForBulkTickets(
            _lotteries[_lotteryId].priceTicketInLotteryToken,
            _ticketNumbers.length
        );

        // Transfer nonas to this contract
        nona.safeTransferFrom(
            address(msg.sender),
            address(this),
            amountLotteryTokenToTransfer
        );

        // Increment the total amount collected for the lottery round
        // _lotteries[_lotteryId].amountCollectedInLotteryToken += amountLotteryTokenToTransfer;

        // Increment the total player for the lottery round if user buy ticket for the first time
        if (_userTicketIdsPerLotteryId[msg.sender][_lotteryId].length == 0) {
            _playersPerLottery[_lotteryId]++;
        }

        for (uint256 i = 0; i < _ticketNumbers.length; i++) {
            require(
                (_ticketNumbers[i] >= 1000000) &&
                    (_ticketNumbers[i] <= 1999999),
                "Outside range"
            );

            uint32 thisTicketNumber = _revertNumber(_ticketNumbers[i]);

            _numberTicketsPerLotteryId[_lotteryId][
                1 + (thisTicketNumber % 10)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                11 + (thisTicketNumber % 100)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                111 + (thisTicketNumber % 1000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                1111 + (thisTicketNumber % 10000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                11111 + (thisTicketNumber % 100000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                111111 + (thisTicketNumber % 1000000)
            ]++;

            _userTicketIdsPerLotteryId[msg.sender][_lotteryId].push(
                currentTicketId
            );

            _tickets[currentTicketId] = Ticket({
                number: _ticketNumbers[i],
                owner: msg.sender
            });

            // Increase lottery ticket number
            currentTicketId++;
        }

        emit TicketsPurchase(msg.sender, _lotteryId, _ticketNumbers.length);
    }

    /**
     * @notice Close lottery
     * @param _lotteryId: lottery id
     * @dev Callable by operator
     */
    function closeLottery(uint256 _lotteryId)
        external
        override
        onlyOperator
        nonReentrant
    {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "Lottery not open"
        );
        require(
            block.timestamp > _lotteries[_lotteryId].endTime,
            "Lottery not over"
        );
        _lotteries[_lotteryId].firstTicketIdNextLottery = currentTicketId;

        // Request a random number from the generator based on a seed
        randomGenerator.requestRandomWords();

        _lotteries[_lotteryId].status = Status.Close;

        emit LotteryClose(_lotteryId, currentTicketId);
    }

    /**
     * @notice Draw the final number, calculate reward in nona per group, and make lottery claimable
     * @param _lotteryId: lottery id
     * @param _autoInjection: reinjects funds into next lottery (vs. withdrawing all)
     * @dev Callable by operator
     */
    function drawFinalNumberAndMakeLotteryClaimable(
        uint256 _lotteryId,
        bool _autoInjection
    ) external override onlyOperator nonReentrant {
        require(
            _lotteries[_lotteryId].status == Status.Close,
            "Lottery not close"
        );
        require(
            _lotteryId == randomGenerator.viewLatestLotteryId(),
            "Numbers not drawn"
        );

        // Calculate the finalNumber based on the randomResult generated by ChainLink's fallback
        uint32 finalNumber = randomGenerator.viewRandomResult();

        // Initialize a number to count addresses in the previous bracket
        uint256 numberAddressesInPreviousBracket;

        // Calculate the amount to share post-rollover fee
        uint256 amountToShareToWinners = (
            ((_lotteries[_lotteryId].amountCollectedInLotteryToken) *
                (BASE_DENOMINATOR - _lotteries[_lotteryId].rolloverFee))
        ) / BASE_DENOMINATOR;

        // Initializes the amount to withdraw to rollover
        uint256 amountToWithdrawToRollover;

        // Calculate prizes in nona for each bracket by starting from the highest one
        for (uint32 i = 0; i < 6; i++) {
            uint32 j = 5 - i;
            uint32 transformedWinningNumber = _bracketCalculator[j] +
                (_revertNumber(finalNumber) % (uint32(10)**(j + 1)));

            _lotteries[_lotteryId].countWinnersPerBracket[j] =
                _numberTicketsPerLotteryId[_lotteryId][
                    transformedWinningNumber
                ] -
                numberAddressesInPreviousBracket;

            // A. If number of users for this _bracket number is superior to 0
            if (
                (_numberTicketsPerLotteryId[_lotteryId][
                    transformedWinningNumber
                ] - numberAddressesInPreviousBracket) != 0
            ) {
                // B. If rewards at this bracket are > 0, calculate, else, report the numberAddresses from previous bracket
                if (_lotteries[_lotteryId].rewardsBreakdown[j] != 0) {
                    _lotteries[_lotteryId].wethPerBracket[j] =
                        ((_lotteries[_lotteryId].rewardsBreakdown[j] *
                            amountToShareToWinners) /
                            (_numberTicketsPerLotteryId[_lotteryId][
                                transformedWinningNumber
                            ] - numberAddressesInPreviousBracket)) /
                        BASE_DENOMINATOR;

                    // Update numberAddressesInPreviousBracket
                    numberAddressesInPreviousBracket = _numberTicketsPerLotteryId[
                        _lotteryId
                    ][transformedWinningNumber];
                }
                // C. No nona to distribute, they are added to the amount to withdraw to burn address
            } else {
                _lotteries[_lotteryId].wethPerBracket[j] = 0;

                amountToWithdrawToRollover +=
                    (_lotteries[_lotteryId].rewardsBreakdown[j] *
                        amountToShareToWinners) /
                    BASE_DENOMINATOR;
            }
        }

        // Update internal statuses for lottery
        _lotteries[_lotteryId].finalNumber = finalNumber;
        _lotteries[_lotteryId].status = Status.Claimable;

        if (_autoInjection) {
            pendingInjectionNextLottery = amountToWithdrawToRollover;
            amountToWithdrawToRollover = 0;
        }

        pendingInjectionNextLottery += (_lotteries[_lotteryId]
            .amountCollectedInLotteryToken - amountToShareToWinners);

        emit LotteryNumberDrawn(
            currentLotteryId,
            finalNumber,
            numberAddressesInPreviousBracket
        );
    }

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _lotteryId: lottery id
     * @param _ticketIds: array of ticket ids
     * @param _brackets: array of brackets for the ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external override notContract nonReentrant whenNotPaused {
        require(_ticketIds.length == _brackets.length, "Not same length");
        require(_ticketIds.length != 0, "Length must be >0");
        require(
            _ticketIds.length <= maxNumberTicketsPerBuyOrClaim,
            "Too many tickets"
        );
        require(
            _lotteries[_lotteryId].status == Status.Claimable,
            "Lottery not claimable"
        );

        // Initializes the rewardInLotteryTokenToTransfer
        uint256 rewardInLotteryTokenToTransfer;

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            require(_brackets[i] < 6, "Bracket out of range"); // Must be between 0 and 5

            uint256 thisTicketId = _ticketIds[i];

            require(
                _lotteries[_lotteryId].firstTicketIdNextLottery > thisTicketId,
                "TicketId too high"
            );
            require(
                _lotteries[_lotteryId].firstTicketId <= thisTicketId,
                "TicketId too low"
            );
            require(
                msg.sender == _tickets[thisTicketId].owner,
                "Not the owner"
            );

            // Update the lottery ticket owner to 0x address
            _tickets[thisTicketId].owner = address(0);

            uint256 rewardForTicketId = _calculateRewardsForTicketId(
                _lotteryId,
                thisTicketId,
                _brackets[i]
            );

            // Check user is claiming the correct bracket
            require(rewardForTicketId != 0, "No prize for this bracket");

            if (_brackets[i] != 5) {
                require(
                    _calculateRewardsForTicketId(
                        _lotteryId,
                        thisTicketId,
                        _brackets[i] + 1
                    ) == 0,
                    "Bracket must be higher"
                );
            }

            // Increment the reward to transfer
            rewardInLotteryTokenToTransfer += rewardForTicketId;
        }

        // Transfer weth to msg.sender
        IERC20(weth).safeTransfer(msg.sender, rewardInLotteryTokenToTransfer);

        emit TicketsClaim(
            msg.sender,
            rewardInLotteryTokenToTransfer,
            _lotteryId,
            _ticketIds.length
        );
    }

    /**
     * @notice Inject ETH
     * @param _lotteryId: lottery id
     * @param _amount: amount to inject in ETH
     * @dev Callable by owner or injector address
     */
    function injectETH(uint256 _lotteryId, uint256 _amount)
        external
        payable
        override
        onlyOwnerOrInjector
    {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "Lottery not open"
        );
        require(msg.value > 0, "Quantity must be > 0");
        require(_amount == msg.value, "Amount != msg.value");

        // Converts sent ETH to WETH in contract
        IWETH(weth).deposit{ value: msg.value }();
        _lotteries[_lotteryId].amountCollectedInLotteryToken += _amount;

        emit LotteryInjection(_lotteryId, _amount);
    }

    /**
     * @notice Inject WETH
     * @param _lotteryId: lottery id
     * @param _amount: amount to inject in WETH
     * @dev Callable by owner or injector address
     */
    function injectWETH(uint256 _lotteryId, uint256 _amount)
        external
        override
        onlyOwnerOrInjector
    {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "Lottery not open"
        );

        IERC20(weth).safeTransferFrom(address(msg.sender), address(this), _amount);
        _lotteries[_lotteryId].amountCollectedInLotteryToken += _amount;

        emit LotteryInjection(_lotteryId, _amount);
    }

    /**
     * @notice It allows the admin to recover tokens except WETH sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(_tokenAddress != address(weth), "Cannot be WETH");

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Change the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * It is necessary to wait for the VRF response before starting a round.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     */
    function changeRandomGenerator(address _randomGeneratorAddress)
        external
        onlyOwner
    {
        require(
            _lotteries[currentLotteryId].status == Status.Claimable,
            "Lottery not in claimable"
        );

        // Request a random number from the generator based on a seed
        IRandomNumberGenerator(_randomGeneratorAddress).requestRandomWords();

        // Calculate the finalNumber based on the randomResult generated by ChainLink's fallback
        IRandomNumberGenerator(_randomGeneratorAddress).viewRandomResult();

        randomGenerator = IRandomNumberGenerator(_randomGeneratorAddress);

        emit NewRandomGenerator(_randomGeneratorAddress);
    }

    /**
     * @notice Set max number of tickets
     * @dev Only callable by owner
     */
    function setMaxNumberTicketsPerBuy(uint256 _maxNumberTicketsPerBuy)
        external
        onlyOwner
    {
        require(_maxNumberTicketsPerBuy != 0, "Must be > 0");
        maxNumberTicketsPerBuyOrClaim = _maxNumberTicketsPerBuy;
    }

    /**
     * @notice Set operator and injector addresses
     * @dev Only callable by owner
     * @param _operatorAddress: address of the operator
     * @param _injectorAddress: address of the injector
     */
    function setOperatorAndInjectorAddresses(
        address _operatorAddress,
        address _injectorAddress
    ) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        require(_injectorAddress != address(0), "Cannot be zero address");

        operatorAddress = _operatorAddress;
        injectorAddress = _injectorAddress;

        emit NewOperatorAndInjectorAddresses(
            _operatorAddress,
            _injectorAddress
        );
    }

    /**
     * @notice Pause contract, preventing users from buying and claiming tickets
     * @dev Only callable by owner
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause contract, allowing users to buy and claim tickets
     * @dev Only callable by owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() external view override returns (uint256) {
        return currentLotteryId;
    }

    /**
     * @notice View lottery information
     * @param _lotteryId: lottery id
     */
    function viewLottery(uint256 _lotteryId)
        external
        view
        returns (Lottery memory)
    {
        return _lotteries[_lotteryId];
    }

    /**
     * @notice View total player in a lottery round
     * @param _lotteryId: lottery id
     */
    function viewTotalUserForLotteryId(uint256 _lotteryId)
        external
        view
        returns (uint256)
    {
        return _playersPerLottery[_lotteryId];
    }

    /**
     * @notice View ticket statuses and numbers for an array of ticket ids
     * @param _ticketIds: array of _ticketId
     */
    function viewNumbersAndStatusesForTicketIds(uint256[] calldata _ticketIds)
        external
        view
        returns (uint32[] memory, bool[] memory)
    {
        uint256 length = _ticketIds.length;
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            ticketNumbers[i] = _tickets[_ticketIds[i]].number;
            if (_tickets[_ticketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                ticketStatuses[i] = false;
            }
        }

        return (ticketNumbers, ticketStatuses);
    }

    /**
     * @notice View rewards for a given ticket, providing a bracket, and lottery id
     * @dev Computations are mostly offchain. This is used to verify a ticket!
     * @param _lotteryId: lottery id
     * @param _ticketId: ticket id
     * @param _bracket: bracket for the ticketId to verify the claim and calculate rewards
     */
    function viewRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) external view returns (uint256) {
        // Check lottery is in claimable status
        if (_lotteries[_lotteryId].status != Status.Claimable) {
            return 0;
        }

        // Check ticketId is within range
        if (
            (_lotteries[_lotteryId].firstTicketIdNextLottery <= _ticketId) ||
            (_lotteries[_lotteryId].firstTicketId > _ticketId)
        ) {
            return 0;
        }

        return _calculateRewardsForTicketId(_lotteryId, _ticketId, _bracket);
    }

    /**
     * @notice View user ticket ids, numbers, and statuses of user for a given lottery
     * @param _user: user address
     * @param _lotteryId: lottery id
     * @param _cursor: cursor to start where to retrieve the tickets
     * @param _size: the number of tickets to retrieve
     */
    function viewUserInfoForLotteryId(
        address _user,
        uint256 _lotteryId,
        uint256 _cursor,
        uint256 _size
    )
        external
        view
        returns (
            uint256[] memory,
            uint32[] memory,
            bool[] memory,
            uint256
        )
    {
        uint256 length = _size;
        uint256 numberTicketsBoughtAtLotteryId = _userTicketIdsPerLotteryId[
            _user
        ][_lotteryId].length;

        if (length > (numberTicketsBoughtAtLotteryId - _cursor)) {
            length = numberTicketsBoughtAtLotteryId - _cursor;
        }

        uint256[] memory lotteryTicketIds = new uint256[](length);
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            lotteryTicketIds[i] = _userTicketIdsPerLotteryId[_user][_lotteryId][
                i + _cursor
            ];
            ticketNumbers[i] = _tickets[lotteryTicketIds[i]].number;

            // True = ticket claimed
            if (_tickets[lotteryTicketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                // ticket not claimed (includes the ones that cannot be claimed)
                ticketStatuses[i] = false;
            }
        }

        return (
            lotteryTicketIds,
            ticketNumbers,
            ticketStatuses,
            _cursor + length
        );
    }

    /**
     * @notice Check user ticket ids for price of a given lottery
     * @param _user: user address
     * @param _lotteryId: lottery id
     */
    function checkUserInfoForPrice(address _user, uint256 _lotteryId)
        external
        view
        returns (
            uint256[] memory,
            uint32[] memory,
            uint32[] memory,
            bool[] memory
        )
    {
        uint256 numberTicketsBoughtAtLotteryId = _userTicketIdsPerLotteryId[
            _user
        ][_lotteryId].length;

        uint256[] memory lotteryTicketIds = new uint256[](
            numberTicketsBoughtAtLotteryId
        );
        uint32[] memory ticketNumbers = new uint32[](
            numberTicketsBoughtAtLotteryId
        );
        uint32[] memory brackets = new uint32[](numberTicketsBoughtAtLotteryId);
        bool[] memory ticketWon = new bool[](numberTicketsBoughtAtLotteryId);

        for (uint32 i = 0; i < numberTicketsBoughtAtLotteryId; i++) {
            lotteryTicketIds[i] = _userTicketIdsPerLotteryId[_user][_lotteryId][
                i
            ];
            ticketNumbers[i] = _tickets[lotteryTicketIds[i]].number;
            brackets[i] = 0;
            ticketWon[i] = false;
            // Check for all bracket for price won, start from the highest
            for (uint32 j = 5; j >= 0; j--) {
                uint256 price = _calculateRewardsForTicketId(
                    _lotteryId,
                    lotteryTicketIds[i],
                    j
                );
                if (price != 0) {
                    brackets[i] = j;
                    ticketWon[i] = true;
                    break;
                }
            }
        }

        return (lotteryTicketIds, ticketNumbers, brackets, ticketWon);
    }

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
     * @notice Calculate the revert number of the ticket
     * @param _ticketNumber: number of purchased ticket that need reverting
     */
    function _revertNumber(uint32 _ticketNumber)
        internal
        pure
        returns (uint32)
    {
        uint32 revertNumber = 1000000;
        for (uint32 i = 0; i < 6; i++) {
            uint32 j = 5 - i;
            revertNumber += (_ticketNumber % 10) * (uint32(10)**(j));
            _ticketNumber = _ticketNumber / 10;
        }
        return revertNumber;
    }

    /**
     * @notice Calculate final price for bulk of tickets
     * @param _priceTicket: price of a ticket
     * @param _numberTickets: number of tickets purchased
     */
    function _calculateTotalPriceForBulkTickets(
        uint256 _priceTicket,
        uint256 _numberTickets
    ) internal pure returns (uint256) {
        return _priceTicket * _numberTickets;
    }

    /**
     * @notice Calculate rewards for a given ticket
     * @param _lotteryId: lottery id
     * @param _ticketId: ticket id
     * @param _bracket: bracket for the ticketId to verify the claim and calculate rewards
     */
    function _calculateRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) internal view returns (uint256) {
        // Retrieve the winning number combination
        uint32 winningTicketNumber = _revertNumber(
            _lotteries[_lotteryId].finalNumber
        );

        // Retrieve the user number combination from the ticketId
        uint32 userNumber = _revertNumber(_tickets[_ticketId].number);

        // Apply transformation to verify the claim provided by the user is true
        uint32 transformedWinningNumber = _bracketCalculator[_bracket] +
            (winningTicketNumber % (uint32(10)**(_bracket + 1)));

        uint32 transformedUserNumber = _bracketCalculator[_bracket] +
            (userNumber % (uint32(10)**(_bracket + 1)));

        // Confirm that the two transformed numbers are the same, if not throw
        if (transformedWinningNumber == transformedUserNumber) {
            return _lotteries[_lotteryId].wethPerBracket[_bracket];
        } else {
            return 0;
        }
    }

    /**
        * Fallback function to receive native ETH sent to this contract
    */
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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

    constructor() {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
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
        require(paused(), "Pausable: not paused");
        _;
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface INoNationLottery {
    /**
     * @notice Start the lottery
     * @dev Callable by operator
     * @param _endTime: endTime of the lottery
     * @param _priceTicketInNONA: price of a ticket in NONA
     * @param _rewardsBreakdown: breakdown of rewards per bracket (must sum to 10,000)
     * @param _treasuryFee: treasury fee (10,000 = 100%, 100 = 1%)
     */
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicketInNONA,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external;

    /**
     * @notice Buy tickets for the current lottery
     * @param _lotteryId: lotteryId
     * @param _ticketNumbers: array of ticket numbers between 1,000,000 and 1,999,999
     * @dev Callable by users
     */
    function buyTickets(uint256 _lotteryId, uint32[] calldata _ticketNumbers) external;

    /**
     * @notice Close lottery
     * @param _lotteryId: lottery id
     * @dev Callable by operator
     */
    function closeLottery(uint256 _lotteryId) external;

    /**
     * @notice Draw the final number, calculate reward in NONA per group, and make lottery claimable
     * @param _lotteryId: lottery id
     * @param _autoInjection: reinjects funds into next lottery (vs. withdrawing all)
     * @dev Callable by operator
     */
    function drawFinalNumberAndMakeLotteryClaimable(uint256 _lotteryId, bool _autoInjection) external;

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _lotteryId: lottery id
     * @param _ticketIds: array of ticket ids
     * @param _brackets: array of brackets for the ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external;

    /**
     * @notice Inject ETH
     * @param _lotteryId: lottery id
     * @param _amount: amount to inject in NONA token
     * @dev Callable by operator
     */
    function injectETH(uint256 _lotteryId, uint256 _amount) external payable;

    /**
     * @notice Inject WETH
     * @param _lotteryId: lottery id
     * @param _amount: amount to inject in NONA token
     * @dev Callable by operator
     */
    function injectWETH(uint256 _lotteryId, uint256 _amount) external;

    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IRandomNumberGenerator {
    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandomWords() external;

    /**
     * View latest lotteryId numbers
     */
    function viewLatestLotteryId() external view returns (uint256);

    /**
     * Views random result
     */
    function viewRandomResult() external view returns (uint32);
}

// SPDX-License-Identifier: GNU
pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

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