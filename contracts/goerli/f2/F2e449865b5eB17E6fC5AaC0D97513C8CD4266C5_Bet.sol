// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IBullRun.sol";
import "../interfaces/ITopia.sol";
import "../interfaces/IHUB.sol";
import "../interfaces/ICoinFlip.sol";

contract Bet is Ownable, ReentrancyGuard {

    IBullRun private BullRunInterface;
    ITopia private TopiaInterface;
    IHUB private HubInterface;
    ICoinFlip private CoinFlipInterface;
    
    address payable public RandomizerContract; // VRF contract to decide nft stealing
    address payable public dev;
    uint256 public currentEncierroId; // set to current one
    uint256 public maxDuration;
    uint256 public minDuration;
    uint256 public SEED_COST = 0.0002 ether;
    uint256 public DEV_FEE = .001 ether;

    uint16 public runnerMult = 175;
    uint16 public bullMult = 185;
    uint16 public matadorMult = 200;
    uint16 public alphaMult = 200;

    mapping(uint256 => Encierro) public Encierros; // mapping for Encierro id to unlock corresponding encierro params
    mapping(address => uint256[]) public EnteredEncierros; // list of Encierro ID's that a particular address has bet in
    // GENESIS
    mapping(address => mapping(uint256 => uint16[])) public BetNFTsPerEncierro; // keeps track of each players token IDs bet for each encierro
    mapping(uint16 => mapping(uint256 => NFTBet)) public BetNFTInfo; // tokenID to bet info (each staked NFT is its own separate bet) per session
    // ALPHAS
    mapping(address => mapping(uint256 => uint16[])) public BetAlphasPerEncierro; // keeps track of each players token IDs bet for each encierro
    mapping(uint16 => mapping(uint256 => NFTBet)) public BetAlphaInfo; // tokenID to bet info (each staked NFT is its own separate bet) per session
    // All
    mapping(address => mapping(uint256 => bool)) public HasBet; 
    mapping(address => mapping(uint256 => bool)) public HasClaimed;  

    uint16 public alphaCut = 1000;

    constructor(address _bullRun, address _topia, address _hub, address payable _randomizer, address _coinFlip) {
        BullRunInterface = IBullRun(_bullRun);
        TopiaInterface = ITopia(_topia);
        HubInterface = IHUB(_hub);
        CoinFlipInterface = ICoinFlip(_coinFlip);
        RandomizerContract = _randomizer;
        currentEncierroId = 1;
        dev = payable(msg.sender);
    }

    event BetRewardClaimed (address indexed claimer, uint256 amount);
    event BullsWin (uint80 timestamp, uint256 encierroID);
    event RunnersWin (uint80 timestamp, uint256 encierroID);
    event EncierroOpened(
        uint256 indexed encierroId,
        uint256 startTime,
        uint256 endTime,
        uint256 minBet,
        uint256 maxBet
    );

    event BetPlaced(
        address indexed player, 
        uint256 indexed encierroId, 
        uint256 amount,
        uint8 choice,
        uint16[] tokenIDs
    );

    event EncierroClosed(
        uint256 indexed encierroId, 
        uint256 endTime,
        uint16 numRunners,
        uint16 numBulls,
        uint16 numMatadors,
        uint16 numAlphas,
        uint16 numberOfBetsOnRunnersWinning,
        uint16 numberOfBetsOnBullsWinning,
        uint256 topiaBetByRunners, // all TOPIA bet by runners
        uint256 topiaBetByBulls, // all TOPIA bet by bulls
        uint256 topiaBetByMatadors, // all TOPIA bet by matadors
        uint256 topiaBetByAlphas, // all TOPIA bet by alphas
        uint256 topiaBetOnRunners, // all TOPIA bet that runners will win
        uint256 topiaBetOnBulls, // all TOPIA bet that bulls will win
        uint256 totalTopiaCollected
    );

    event CoinFlipped(
        uint256 flipResult,
        uint256 indexed encierroId
    );

    // an individual NFT being bet
    struct NFTBet {
        address player;
        uint256 amount; 
        uint8 choice; // (0) BULLS or (1) RUNNERS;
        uint16 tokenID;
        uint8 typeOfNFT;
    }

    enum Status {
        Closed,
        Open,
        Standby,
        Claimable
    }

    struct Encierro {
        Status status;
        uint256 encierroId; // increments monotonically 
        uint256 startTime; // unix timestamp
        uint256 endTime; // unix timestamp
        uint256 minBet;
        uint256 maxBet;
        uint16 numRunners; // number of runners entered
        uint16 numBulls; // number of bulls entered
        uint16 numMatadors; // number of matadors entered
        uint16 numAlphas; // number of alphas entered
        uint16 numberOfBetsOnRunnersWinning; // # of people betting for runners
        uint16 numberOfBetsOnBullsWinning; // # of people betting for bulls
        uint256 topiaBetByRunners; // all TOPIA bet by runners
        uint256 topiaBetByBulls; // all TOPIA bet by bulls
        uint256 topiaBetByMatadors; // all TOPIA bet by matadors
        uint256 topiaBetByAlphas; // all TOPIA bet by alphas
        uint256 topiaBetOnRunners; // all TOPIA bet that runners will win
        uint256 topiaBetOnBulls; // all TOPIA bet that bulls will win
        uint256 totalTopiaCollected; // total TOPIA collected from bets for the entire round
        uint256 flipResult; // 0 for bulls, 1 for runners
    }
    // ---- setters:

    function setHUB(address _hub) external onlyOwner {
        HubInterface = IHUB(_hub);
    }

    function setTopiaToken(address _topiaToken) external onlyOwner {
        TopiaInterface = ITopia(_topiaToken);
    }

    function setRNGContract(address _coinFlipContract) external onlyOwner {
        CoinFlipInterface = ICoinFlip(_coinFlipContract);
    }

    function setRandomizer(address _randomizer) external onlyOwner {
        RandomizerContract = payable(_randomizer);
    }

    function setSeedCost(uint256 _cost, uint256 _fee) external onlyOwner {
        SEED_COST = _cost;
        DEV_FEE = _fee;
    }

    function setBullRunContract(address _bullRun) external onlyOwner {
        BullRunInterface = IBullRun(_bullRun);
    }

    function setWinMultipliers(uint16 _runner, uint16 _bull, uint16 _matador, uint16 _alpha) external onlyOwner {
        runnerMult = _runner;
        bullMult = _bull;
        matadorMult = _matador;
        alphaMult = _alpha;
    }
    
    function setAlphaCut(uint16 _cut) external onlyOwner {
        alphaCut = _cut;
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    function getStakedNFTInfo(uint16 _tokenID) public returns (uint16, address, uint80, uint8, uint256) {
        uint16 tokenID;
        address owner;
        uint80 stakeTimestamp;
        uint8 typeOfNFT;
        uint256 value;
        (tokenID, owner, stakeTimestamp, typeOfNFT, value) = BullRunInterface.StakedNFTInfo(_tokenID);

        return (tokenID, owner, stakeTimestamp, typeOfNFT, value);
    }

    function getStakedAlphaInfo(uint16 _tokenID) public returns (uint16, address, uint80, uint8, uint256) {
        uint16 tokenID;
        address owner;
        uint80 stakeTimestamp;
        uint8 typeOfNFT;
        uint256 value;
        (tokenID, owner, stakeTimestamp, typeOfNFT, value) = BullRunInterface.StakedAlphaInfo(_tokenID);

        return (tokenID, owner, stakeTimestamp, typeOfNFT, value);
    }

    function setMinMaxDuration(uint256 _min, uint256 _max) external onlyOwner {
        minDuration = _min;
        maxDuration = _max;
    }

    function betMany(uint16[] calldata _tokenIds, uint256 _encierroId, uint256 _betAmount, uint8 _choice) external payable
    nonReentrant {
        require(msg.value == SEED_COST + DEV_FEE, "seed cost not met");
        require(Encierros[_encierroId].endTime > block.timestamp , "Betting has ended");
        require(TopiaInterface.balanceOf(address(msg.sender)) >= (_betAmount * _tokenIds.length), "not enough TOPIA");
        require(_choice == 1 || _choice == 0, "Invalid choice");
        require(Encierros[_encierroId].status == Status.Open, "not open");
        require(_betAmount >= Encierros[_encierroId].minBet && _betAmount <= Encierros[_encierroId].maxBet, "Bet not within limits");

        RandomizerContract.transfer(SEED_COST);
        dev.transfer(DEV_FEE);
        uint16 numberOfNFTs = uint16(_tokenIds.length);
        uint256 totalBet = _betAmount * numberOfNFTs;
        for (uint i = 0; i < numberOfNFTs;) {
            address tokenOwner;
            uint8 tokenType;
            (,tokenOwner,,tokenType,) = getStakedNFTInfo(_tokenIds[i]);
            require(tokenOwner == msg.sender, "not owner");

            if (tokenType == 1) {
                betRunner(_tokenIds[i], _encierroId, _betAmount, _choice);
            } else if (tokenType == 2) {
                betBull(_tokenIds[i], _encierroId, _betAmount, _choice);
            } else if (tokenType == 3) {
                betMatador(_tokenIds[i], _encierroId, _betAmount, _choice);
            } else if (tokenType == 0) {
                continue;
            }

            Encierros[_encierroId].totalTopiaCollected += totalBet;
            
            if (_choice == 0) {
                Encierros[_encierroId].numberOfBetsOnBullsWinning += numberOfNFTs; // increase the number of bets on bulls winning by # of NFTs being bet
                Encierros[_encierroId].topiaBetOnBulls += totalBet; // multiply the bet amount per NFT by the number of NFTs
            } else {
                Encierros[_encierroId].numberOfBetsOnRunnersWinning += numberOfNFTs; // increase number of bets on runners...
                Encierros[_encierroId].topiaBetOnRunners += totalBet;
            }

            if (!HasBet[msg.sender][_encierroId]) {
                HasBet[msg.sender][_encierroId] = true;
                EnteredEncierros[msg.sender].push(_encierroId);
            }
            HubInterface.burnFrom(msg.sender, totalBet);
            emit BetPlaced(msg.sender, _encierroId, totalBet, _choice, _tokenIds);
            unchecked{ i++; }
            }
    }

    function betManyAlphas(uint16[] calldata _tokenIds, uint256 _encierroId, uint256 _betAmount, uint8 _choice) external payable
    nonReentrant {
        require(msg.value == SEED_COST + DEV_FEE, "seed cost not met");
        require(Encierros[_encierroId].endTime > block.timestamp , "Betting has ended");
        require(TopiaInterface.balanceOf(address(msg.sender)) >= (_betAmount * _tokenIds.length), "not enough TOPIA");
        require(_choice == 1 || _choice == 0, "Invalid choice");
        require(Encierros[_encierroId].status == Status.Open, "not open");
        require(_betAmount >= Encierros[_encierroId].minBet && _betAmount <= Encierros[_encierroId].maxBet, "Bet not within limits");

        RandomizerContract.transfer(SEED_COST);
        dev.transfer(DEV_FEE);
        uint16 numberOfNFTs = uint16(_tokenIds.length);
        uint256 totalBet = _betAmount * numberOfNFTs;
        for (uint i = 0; i < numberOfNFTs;) {
            address tokenOwner;
            (,tokenOwner,,,) = getStakedAlphaInfo(_tokenIds[i]);
            require(tokenOwner == msg.sender, "not owner");

            betAlpha(_tokenIds[i], _encierroId, _betAmount, _choice);

            Encierros[_encierroId].totalTopiaCollected += totalBet;
            
            if (_choice == 0) {
                Encierros[_encierroId].numberOfBetsOnBullsWinning += numberOfNFTs; // increase the number of bets on bulls winning by # of NFTs being bet
                Encierros[_encierroId].topiaBetOnBulls += totalBet; // multiply the bet amount per NFT by the number of NFTs
            } else {
                Encierros[_encierroId].numberOfBetsOnRunnersWinning += numberOfNFTs; // increase number of bets on runners...
                Encierros[_encierroId].topiaBetOnRunners += totalBet;
            }

            if (!HasBet[msg.sender][_encierroId]) {
                HasBet[msg.sender][_encierroId] = true;
                EnteredEncierros[msg.sender].push(_encierroId);
            }
            HubInterface.burnFrom(msg.sender, totalBet);
            emit BetPlaced(msg.sender, _encierroId, totalBet, _choice, _tokenIds);
            unchecked{ i++; }
        }
    }

    function betRunner(uint16 _runnerID, uint256 _encierroId, uint256 _betAmount, uint8 _choice) internal {
        BetNFTsPerEncierro[msg.sender][_encierroId].push(_runnerID); // add the token IDs being bet to their personal mapping for this session
        BetNFTInfo[_runnerID][_encierroId].player = msg.sender; // map bet token id to caller for this session
        BetNFTInfo[_runnerID][_encierroId].amount = _betAmount; // map bet token id to bet amount for this session
        BetNFTInfo[_runnerID][_encierroId].choice = _choice; // map bet token id to choice for this session
        BetNFTInfo[_runnerID][_encierroId].tokenID = _runnerID; // map bet token id to struct id for this session
        BetNFTInfo[_runnerID][_encierroId].typeOfNFT = 1; // 1 = runner

        Encierros[_encierroId].topiaBetByRunners += _betAmount;
        Encierros[_encierroId].numRunners++;
    }

    function betBull(uint16 _bullID, uint256 _encierroId, uint256 _betAmount, uint8 _choice) internal {
        BetNFTsPerEncierro[msg.sender][_encierroId].push(_bullID); // add the token IDs being bet to their personal mapping for this session
        BetNFTInfo[_bullID][_encierroId].player = msg.sender; // map bet token id to caller for this session
        BetNFTInfo[_bullID][_encierroId].amount = _betAmount; // map bet token id to bet amount for this session
        BetNFTInfo[_bullID][_encierroId].choice = _choice; // map bet token id to choice for this session
        BetNFTInfo[_bullID][_encierroId].tokenID = _bullID; // map bet token id to struct id for this session
        BetNFTInfo[_bullID][_encierroId].typeOfNFT = 2; // 2 = bull

        Encierros[_encierroId].topiaBetByBulls += _betAmount;
        Encierros[_encierroId].numBulls++;
    }

    function betMatador(uint16 _matadorID, uint256 _encierroId, uint256 _betAmount, uint8 _choice) internal {
        BetNFTsPerEncierro[msg.sender][_encierroId].push(_matadorID); // add the token IDs being bet to their personal mapping for this session
        BetNFTInfo[_matadorID][_encierroId].player = msg.sender; // map bet token id to caller for this session
        BetNFTInfo[_matadorID][_encierroId].amount = _betAmount; // map bet token id to bet amount for this session
        BetNFTInfo[_matadorID][_encierroId].choice = _choice; // map bet token id to choice for this session
        BetNFTInfo[_matadorID][_encierroId].tokenID = _matadorID; // map bet token id to struct id for this session
        BetNFTInfo[_matadorID][_encierroId].typeOfNFT = 3; // 3 = matador

        Encierros[_encierroId].topiaBetByMatadors += _betAmount;
        Encierros[_encierroId].numMatadors++;
    }

    function betAlpha(uint16 _alphaID, uint256 _encierroId, uint256 _betAmount, uint8 _choice) internal {
        BetAlphasPerEncierro[msg.sender][_encierroId].push(_alphaID); // add the token IDs being bet to their personal mapping for this session
        BetAlphaInfo[_alphaID][_encierroId].player = msg.sender; // map bet token id to caller for this session
        BetAlphaInfo[_alphaID][_encierroId].amount = _betAmount; // map bet token id to bet amount for this session
        BetAlphaInfo[_alphaID][_encierroId].choice = _choice; // map bet token id to choice for this session
        BetAlphaInfo[_alphaID][_encierroId].tokenID = _alphaID; // map bet token id to struct id for this session
        BetAlphaInfo[_alphaID][_encierroId].typeOfNFT = 0; // 0 = alpha

        Encierros[_encierroId].topiaBetByAlphas += _betAmount;
        Encierros[_encierroId].numAlphas++;
    }

    function claimManyBetRewards() external 
    nonReentrant notContract() {

        uint256 owed; // what caller collects for winning
        for(uint i = 0; i < EnteredEncierros[msg.sender].length;) {
            uint256 sessionID = EnteredEncierros[msg.sender][i];
            if(Encierros[sessionID].status == Status.Claimable && !HasClaimed[msg.sender][sessionID] && HasBet[msg.sender][sessionID]) {
                uint8 winningResult = uint8(Encierros[sessionID].flipResult);
                require(winningResult <= 1 , "Invalid flip result");
                for (uint16 z = 0; z < BetNFTsPerEncierro[msg.sender][sessionID].length;) { // fetch their bet NFT ids for this encierro                    
                    // calculate winnings
                    if (BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].choice == winningResult && 
                        BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].typeOfNFT == 1) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * runnerMult) / 100;

                    } else if (BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].choice == winningResult && 
                               BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].typeOfNFT == 2) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * bullMult) / 100;

                    } else if (BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].choice == winningResult && 
                               BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].typeOfNFT == 3) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetNFTInfo[BetNFTsPerEncierro[msg.sender][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * matadorMult) / 100;
                    } else {
                        unchecked{ z++; }
                        continue;
                    }  
                }

                for (uint16 z = 0; z < BetAlphasPerEncierro[msg.sender][sessionID].length;) { // fetch their bet NFT ids for this encierro                    
                    // calculate winnings
                    if (BetAlphaInfo[BetAlphasPerEncierro[msg.sender][sessionID][z]][sessionID].choice == winningResult) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetAlphaInfo[BetAlphasPerEncierro[msg.sender][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * alphaMult) / 100;

                    } else {
                        continue;
                    }
                    unchecked{ z++; }
                }

                HasClaimed[msg.sender][sessionID] = true;
            } else {
                unchecked{ i++; }
                continue;
            }
        }

        HubInterface.pay(msg.sender, owed);
        emit BetRewardClaimed(msg.sender, owed);
    }

    // Encierro SESSION LOGIC ---------------------------------------------------- 

    function startEncierro(
        uint256 _endTime,
        uint256 _minBet,
        uint256 _maxBet) 
        external
        nonReentrant
        {
        require(
            (currentEncierroId == 1) || 
            (Encierros[currentEncierroId].status == Status.Claimable), "session not claimable");

        require(((_endTime - block.timestamp) >= minDuration) && ((_endTime - block.timestamp) <= maxDuration), "invalid time");

        currentEncierroId++;

        Encierros[currentEncierroId] = Encierro({
            status: Status.Open,
            encierroId: currentEncierroId,
            startTime: block.timestamp,
            endTime: _endTime,
            minBet: _minBet,
            maxBet: _maxBet,
            numRunners: 0,
            numBulls: 0,
            numMatadors: 0,
            numAlphas: 0,
            numberOfBetsOnRunnersWinning: 0,
            numberOfBetsOnBullsWinning: 0,
            topiaBetByRunners: 0,
            topiaBetByBulls: 0,
            topiaBetByMatadors: 0,
            topiaBetByAlphas: 0,
            topiaBetOnRunners: 0,
            topiaBetOnBulls: 0,
            totalTopiaCollected: 0,
            flipResult: 2 // init to 2 to avoid conflict with 0 (bulls) or 1 (runners). is set to 0 or 1 later depending on coin flip result.
        });
        
        emit EncierroOpened(
            currentEncierroId,
            block.timestamp,
            _endTime,
            _minBet,
            _maxBet
        );
    }

    // bulls = 0, runners = 1
    function closeEncierro(uint256 _encierroId) external nonReentrant {
        require(Encierros[_encierroId].status == Status.Open , "must be open first");
        require(block.timestamp > Encierros[_encierroId].endTime, "not over yet");
        CoinFlipInterface.requestRandomWords();
        Encierros[_encierroId].status = Status.Closed;
        emit EncierroClosed(
            _encierroId,
            block.timestamp,
            Encierros[_encierroId].numRunners,
            Encierros[_encierroId].numBulls,
            Encierros[_encierroId].numMatadors,
            Encierros[_encierroId].numAlphas,
            Encierros[_encierroId].numberOfBetsOnRunnersWinning,
            Encierros[_encierroId].numberOfBetsOnBullsWinning,
            Encierros[_encierroId].topiaBetByRunners,
            Encierros[_encierroId].topiaBetByBulls,
            Encierros[_encierroId].topiaBetByMatadors,
            Encierros[_encierroId].topiaBetByAlphas,
            Encierros[_encierroId].topiaBetOnRunners,
            Encierros[_encierroId].topiaBetOnBulls,
            Encierros[_encierroId].totalTopiaCollected
        );
    }

    function flipCoinAndMakeClaimable(uint256 _encierroId) external nonReentrant notContract() returns (uint256) {
        require(_encierroId <= currentEncierroId , "Nonexistent session!");
        require(Encierros[_encierroId].status == Status.Closed , "must be closed first");
        uint256 encierroFlipResult = _flipCoin();
        Encierros[_encierroId].flipResult = encierroFlipResult;

        if (encierroFlipResult == 0) { // if bulls win
            uint256 amountToAlphas = (Encierros[_encierroId].topiaBetOnRunners * alphaCut) / 10000;
            BullRunInterface.payAlphaTax(amountToAlphas);
        } else { // if runners win
            uint256 amountToAlphas = (Encierros[_encierroId].topiaBetOnBulls * alphaCut) / 10000;
            BullRunInterface.payAlphaTax(amountToAlphas);
        }

        Encierros[_encierroId].status = Status.Claimable;
        return encierroFlipResult;
    }

    function _flipCoin() internal returns (uint256) {
        uint256 result = CoinFlipInterface.oneOutOfTwo();
        Encierros[currentEncierroId].status = Status.Standby;
        if (result == 0) {
            Encierros[currentEncierroId].flipResult = 0;
            emit BullsWin(uint80(block.timestamp), currentEncierroId);
        } else {
            Encierros[currentEncierroId].flipResult = 1;
            emit RunnersWin(uint80(block.timestamp), currentEncierroId);
        }
        emit CoinFlipped(result, currentEncierroId);
        return result;
    }

    function viewEncierroById(uint256 _encierroId) external view returns (Encierro memory) {
        return Encierros[_encierroId];
    }

    function getEnteredEncierrosLength(address _better) external view returns (uint256) {
        return EnteredEncierros[_better].length;
    }

    function getUserNFTsPerEncierro(address account, uint256 _id) external view returns (uint16[] memory tokenIds) {
        uint256 length = BetNFTsPerEncierro[account][_id].length;
        tokenIds = new uint16[](length);
        for(uint i = 0; i < length;) {
            tokenIds[i] = BetNFTsPerEncierro[account][_id][i];
            unchecked{ i++; }
        }
    }

    function getUnclaimedBetRewards(address account) external view returns (uint256){
        uint256 owed; // what caller collects for winning
        for(uint i = 0; i < EnteredEncierros[account].length;) {
            uint256 sessionID = EnteredEncierros[account][i];
            if(Encierros[sessionID].status == Status.Claimable && !HasClaimed[account][sessionID] && HasBet[account][sessionID]) {
                uint8 winningResult = uint8(Encierros[sessionID].flipResult);
                require(winningResult <= 1 , "Invalid flip result");
                for (uint16 z = 0; z < BetNFTsPerEncierro[account][sessionID].length;) { // fetch their bet NFT ids for this encierro                    
                    // calculate winnings
                    if (BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].choice == winningResult && 
                        BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].typeOfNFT == 1) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * runnerMult) / 100;

                    } else if (BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].choice == winningResult && 
                               BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].typeOfNFT == 2) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * bullMult) / 100;

                    } else if (BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].choice == winningResult && 
                               BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].typeOfNFT == 3) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetNFTInfo[BetNFTsPerEncierro[account][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * matadorMult) / 100;
                    } else {
                        unchecked{ z++; }
                        continue;
                    }
                }

                for (uint16 z = 0; z < BetAlphasPerEncierro[account][sessionID].length;) { // fetch their bet NFT ids for this encierro                    
                    // calculate winnings
                    if (BetAlphaInfo[BetAlphasPerEncierro[account][sessionID][z]][sessionID].choice == winningResult) {
                            // get how much topia was bet on this NFT id in this session
                            uint256 topiaBetOnThisNFT = BetAlphaInfo[BetAlphasPerEncierro[account][sessionID][z]][sessionID].amount;
                            owed += (topiaBetOnThisNFT * alphaMult) / 100;

                    } else {
                        continue;
                    }
                }

            } else {
                continue;
            }
            unchecked{ i++; }
        }
        return owed;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ICoinFlip {
    
    function oneOutOfTwo() external view returns (uint256);
    function requestRandomWords() external;
    
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IHUB {
    function balanceOf(address owner) external view returns (uint256);
    function pay(address _to, uint256 _amount) external;
    function burnFrom(address _to, uint256 _amount) external;
    // *** STEAL
    function stealGenesis(uint16 _id, uint256 seed, uint8 _gameId, uint8 identifier, address _victim) external returns (address thief);
    function stealMigratingGenesis(uint16 _id, uint256 seed, uint8 _gameId, address _victim, bool returningFromWastelands) external returns (address thief);
    function migrate(uint16 _id, address _originalOwner, uint8 _gameId,  bool returningFromWastelands) external;
    // *** RETURN AND RECEIVE
    function returnGenesisToOwner(address _returnee, uint16 _id, uint8 identifier, uint8 _gameIdentifier) external;
    function receieveManyGenesis(address _originalOwner, uint16[] memory _ids, uint8[] memory identifiers, uint8 _gameIdentifier) external;
    function returnAlphaToOwner(address _returnee, uint16 _id, uint8 _gameIdentifier) external;
    function receiveAlpha(address _originalOwner, uint16 _id, uint8 _gameIdentifier) external;
    function returnRatToOwner(address _returnee, uint16 _id) external;
    function receiveRat(address _originalOwner, uint16 _id) external;
    // *** BULLRUN
    function getRunnerOwner(uint16 _id) external view returns (address);
    function getMatadorOwner(uint16 _id) external view returns (address);
    function getBullOwner(uint16 _id) external view returns (address);
    function bullCount() external view returns (uint16);
    function matadorCount() external view returns (uint16);
    function runnerCount() external view returns (uint16);
    // *** MOONFORCE
    function getCadetOwner(uint16 _id) external view returns (address); 
    function getAlienOwner(uint16 _id) external view returns (address);
    function getGeneralOwner(uint16 _id) external view returns (address);
    function cadetCount() external view returns (uint16); 
    function alienCount() external view returns (uint16); 
    function generalCount() external view returns (uint16);
    // *** DOGE WORLD
    function getCatOwner(uint16 _id) external view returns (address);
    function getDogOwner(uint16 _id) external view returns (address);
    function getVetOwner(uint16 _id) external view returns (address);
    function catCount() external view returns (uint16);
    function dogCount() external view returns (uint16);
    function vetCount() external view returns (uint16);
    // *** PYE MARKET
    function getBakerOwner(uint16 _id) external view returns (address);
    function getFoodieOwner(uint16 _id) external view returns (address);
    function getShopOwnerOwner(uint16 _id) external view returns (address);
    function bakerCount() external view returns (uint16);
    function foodieCount() external view returns (uint16);
    function shopOwnerCount() external view returns (uint16);
    // *** ALPHAS AND RATS
    function alphaCount(uint8 _gameIdentifier) external view returns (uint16);
    function ratCount() external view returns (uint16);
    // *** NFT GROUP FUNCTION
    function createGroup(uint16[] calldata _ids, address _creator, uint8 _gameIdentifier) external;
    function addToGroup(uint16 _id, address _creator, uint8 _gameIdentifier) external;
    function unstakeGroup(address _creator, uint8 _gameIdentifier) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITopia {

    function burn(uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;  
    function burnFrom(address _from, uint256 _amount) external;
    function decimals() external pure returns (uint8);
    function balanceOf(address owner) external view returns (uint);
    function updateOriginAccess() external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool);
}

// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.15;

interface IBullRun {
    function StakedNFTInfo(uint16 _tokenID) external returns 
        (uint16 tokenID, address owner, uint80 stakeTimestamp, uint8 typeOfNFT, uint256 value);
    function StakedAlphaInfo(uint16 _tokenID) external returns 
        (uint16 tokenID, address owner, uint80 stakeTimestamp, uint8 typeOfNFT, uint256 value);
    function IsNFTStaked(uint16) external view returns (bool);
    function payAlphaTax(uint256 _amount) external;
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