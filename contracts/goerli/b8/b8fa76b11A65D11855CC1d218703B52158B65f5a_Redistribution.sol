// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./PostageStamp.sol";
import "./PriceOracle.sol";
import "./Staking.sol";

/**
 * @title Redistribution contract
 * @author The Swarm Authors
 * @dev Implements a Schelling Co-ordination game to form consensus around the Reserve Commitment hash. This takes
 * place in three phases: _commit_, _reveal_ and _claim_.
 *
 * A node, upon establishing that it _isParticipatingInUpcomingRound_, i.e. it's overlay falls within proximity order
 * of its reported depth with the _currentRoundAnchor_, prepares a "reserve commitment hash" using the chunks
 * it currently stores in its reserve and calculates the "storage depth" (see Bee for details). These values, if calculated
 * honestly, and with the right chunks stored, should be the same for every node in a neighbourhood. This is the Schelling point.
 * Each eligible node can then use these values, together with a random, single use, secret  _revealNonce_ and their
 * _overlay_ as the pre-image values for the obsfucated _commit_, using the _wrapCommit_ method.
 *
 * Once the _commit_ round has elapsed, participating nodes must provide the values used to calculate their obsfucated
 * _commit_ hash, which, once verified for correctness and proximity to the anchor are retained in the _currentReveals_.
 * Nodes that have commited but do not reveal the correct values used to create the pre-image will have their stake
 * "frozen" for a period of rounds proportional to their reported depth.
 *
 * During the _reveal_ round, randomness is updated after every successful reveal. Once the reveal round is concluded,
 * the _currentRoundAnchor_ is updated and users can determine if they will be eligible their overlay will be eligible
 * for the next commit phase using _isParticipatingInUpcomingRound_.
 *
 * When the _reveal_ phase has been concluded, the claim phase can begin. At this point, the truth teller and winner
 * are already determined. By calling _isWinner_, an applicant node can run the relevant logic to determine if they have
 * been selected as the beneficiary of this round. When calling _claim_, the current pot from the PostageStamp contract
 * is withdrawn and transferred to that beneficiaries address. Nodes that have revealed values that differ from the truth,
 * have their stakes "frozen" for a period of rounds proportional to their reported depth.
 */
contract Redistribution is AccessControl, Pausable {
    // An eligible user may commit to an _obfuscatedHash_ during the commit phase...
    struct Commit {
        bytes32 overlay;
        address owner;
        uint256 stake;
        bytes32 obfuscatedHash;
        bool revealed;
        uint256 revealIndex;
    }
    // ...then provide the actual values that are the constituents of the pre-image of the _obfuscatedHash_
    // during the reveal phase.
    struct Reveal {
        address owner;
        bytes32 overlay;
        uint256 stake;
        uint256 stakeDensity;
        bytes32 hash;
        uint8 depth;
    }

    // The address of the linked PostageStamp contract.
    PostageStamp public PostageContract;
    // The address of the linked PriceOracle contract.
    PriceOracle public OracleContract;
    // The address of the linked Staking contract.
    StakeRegistry public Stakes;

    // Commits for the current round.
    Commit[] public currentCommits;
    // Reveals for the current round.
    Reveal[] public currentReveals;

    // Role allowed to pause.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant penaltyMultiplierDisagreement = 3;
    uint256 public constant penaltyMultiplierNonRevealed = 7;

    // Maximum value of the keccack256 hash.
    bytes32 MaxH = bytes32(0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);

    // The current anchor that being processed for the reveal and claim phases of the round.
    bytes32 currentRevealRoundAnchor;

    // The current random value from which we will random.
    // inputs for selection of the truth teller and beneficiary.
    bytes32 seed;

    // The miniumum stake allowed to be staked using the Staking contract.
    uint256 public minimumStake = 100000000000000000;

    // The number of the currently active round phases.
    uint256 public currentCommitRound;
    uint256 public currentRevealRound;
    uint256 public currentClaimRound;

    // The length of a round in blocks.
    uint256 public roundLength = 152;

    // The reveal of the winner of the last round.
    Reveal public winner;

    /**
    * @dev Pause the contract. The contract is provably stopped by renouncing
     the pauser role and the admin role after pausing, can only be called by the `PAUSER`
     */
    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "only pauser can pause");
        _pause();
    }

    /**
     * @dev Unpause the contract, can only be called by the pauser when paused
     */
    function unPause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "only pauser can unpause");
        _unpause();
    }

    /**
     * @param staking the address of the linked Staking contract.
     * @param postageContract the address of the linked PostageStamp contract.
     * @param oracleContract the address of the linked PriceOracle contract.
     */
    constructor(
        address staking,
        address postageContract,
        address oracleContract
    ) {
        Stakes = StakeRegistry(staking);
        PostageContract = PostageStamp(postageContract);
        OracleContract = PriceOracle(oracleContract);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Emitted when the winner of a round is selected in the claim phase.
     */
    event WinnerSelected(Reveal winner);

    /**
     * @dev Emitted when the truth oracle of a round is selected in the claim phase.
     */
    event TruthSelected(bytes32 hash, uint8 depth);

    // Next two events to be removed after testing phase pending some other usefulness being found.
    /**
     * @dev Emits the number of commits being processed by the claim phase.
     */
    event CountCommits(uint256 _count);

    /**
     * @dev Emits the number of reveals being processed by the claim phase.
     */
    event CountReveals(uint256 _count);

    /**
     * @dev Logs that an overlay has committed
     */
    event Committed(uint256 roundNumber, bytes32 overlay);

    /**
     * @dev Logs that an overlay has revealed
     */
    event Revealed(
        uint256 roundNumber,
        bytes32 overlay,
        uint256 stake,
        uint256 stakeDensity,
        bytes32 reserveCommitment,
        uint8 depth
    );

    /**
     * @notice The number of the current round.
     */
    function currentRound() public view returns (uint256) {
        return (block.number / roundLength);
    }

    /**
     * @notice Returns true if current block is during commit phase.
     */
    function currentPhaseCommit() public view returns (bool) {
        if (block.number % roundLength < roundLength / 4) {
            return true;
        }
        return false;
    }

    /**
     * @notice Returns true if current block is during reveal phase.
     */
    function currentPhaseReveal() public view returns (bool) {
        uint256 number = block.number % roundLength;
        if ( number >= roundLength / 4 && number < roundLength / 2 ) {
            return true;
        }
        return false;
    }

    /**
     * @notice Returns true if current block is during claim phase.
     */
    function currentPhaseClaim() public view returns (bool){
        if ( block.number % roundLength >= roundLength / 2 ) {
            return true;
        }
        return false;
    }

    /**
     * @notice Returns true if current block is during reveal phase.
     */
    function currentRoundReveals() public view returns (Reveal[] memory) {
        require(currentPhaseClaim(), "not in claim phase");
        uint256 cr = currentRound();
        require(cr == currentRevealRound, "round received no reveals");
        return currentReveals;
    }

    /**
     * @notice Begin application for a round if eligible. Commit a hashed value for which the pre-image will be
     * subsequently revealed.
     * @dev If a node's overlay is _inProximity_(_depth_) of the _currentRoundAnchor_, that node may compute an
     * _obfuscatedHash_ by providing their _overlay_, reported storage _depth_, reserve commitment _hash_ and a
     * randomly generated, and secret _revealNonce_ to the _wrapCommit_ method.
     * @param _obfuscatedHash The calculated hash resultant of the required pre-image values.
     * @param _overlay The overlay referenced in the pre-image. Must be staked by at least the minimum value,
     * and be derived from the same key pair as the message sender.
     */
    function commit(
        bytes32 _obfuscatedHash,
        bytes32 _overlay,
        uint256 _roundNumber
    ) external whenNotPaused {
        require(currentPhaseCommit(), "not in commit phase");
        require( block.number % roundLength != ( roundLength / 4 ) - 1, "can not commit in last block of phase");
        uint256 cr = currentRound();
        require(cr <= _roundNumber, "commit round over");
        require(cr >= _roundNumber, "commit round not started yet");

        uint256 nstake = Stakes.stakeOfOverlay(_overlay);
        require(nstake >= minimumStake, "stake must exceed minimum");
        require(Stakes.ownerOfOverlay(_overlay) == msg.sender, "owner must match sender");

        require(
            Stakes.lastUpdatedBlockNumberOfOverlay(_overlay) < block.number - 2 * roundLength,
            "must have staked 2 rounds prior"
        );

        // if we are in a new commit phase, reset the array of commits and
        // set the currentCommitRound to be the current one
        if (cr != currentCommitRound) {
            delete currentCommits;
            currentCommitRound = cr;
        }

        uint256 commitsArrayLength = currentCommits.length;

        for (uint256 i = 0; i < commitsArrayLength; i++) {
            require(currentCommits[i].overlay != _overlay, "only one commit each per round");
        }

        currentCommits.push(
            Commit({
                owner: msg.sender,
                overlay: _overlay,
                stake: nstake,
                obfuscatedHash: _obfuscatedHash,
                revealed: false,
                revealIndex: 0
            })
        );

        emit Committed(_roundNumber, _overlay);
    }

    /**
     * @notice Returns the current random seed which is used to determine later utilised random numbers.
     * If rounds have elapsed without reveals, hash the seed with an incremented nonce to produce a new
     * random seed and hence a new round anchor.
     */
    function currentSeed() public view returns (bytes32) {
        uint256 cr = currentRound();
        bytes32 currentSeedValue = seed;

        if (cr > currentRevealRound + 1) {
            uint256 difference = cr - currentRevealRound - 1;
            currentSeedValue = keccak256(abi.encodePacked(currentSeedValue, difference));
        }

        return currentSeedValue;
    }

    /**
     * @notice Returns the seed which will become current once the next commit phase begins.
     * Used to determine what the next round's anchor will be.
     */
    function nextSeed() public view returns (bytes32) {
        uint256 cr = currentRound() + 1;
        bytes32 currentSeedValue = seed;

        if (cr > currentRevealRound + 1) {
            uint256 difference = cr - currentRevealRound - 1;
            currentSeedValue = keccak256(abi.encodePacked(currentSeedValue, difference));
        }

        return currentSeedValue;
    }

    /**
     * @notice Updates the source of randomness. Uses block.difficulty in pre-merge chains, this is substituted
     * to block.prevrandao in post merge chains.
     */
    function updateRandomness() private {
        seed = keccak256(abi.encode(seed, block.difficulty));
    }

    function nonceBasedRandomness(bytes32 nonce) private {
        seed = seed ^ nonce;
    }

    /**
     * @notice Returns true if an overlay address _A_ is within proximity order _minimum_ of _B_.
     * @param A An overlay address to compare.
     * @param B An overlay address to compare.
     * @param minimum Minimum proximity order.
     */
    function inProximity(
        bytes32 A,
        bytes32 B,
        uint8 minimum
    ) public pure returns (bool) {
        if (minimum == 0) {
            return true;
        }
        return uint256(A ^ B) < uint256(2**(256 - minimum));
    }

    /**
     * @notice Hash the pre-image values to the obsfucated hash.
     * @dev _revealNonce_ must be randomly generated, used once and kept secret until the reveal phase.
     * @param _overlay The overlay address of the applicant.
     * @param _depth The reported depth.
     * @param _hash The reserve commitment hash.
     * @param revealNonce A random, single use, secret nonce.
     */
    function wrapCommit(
        bytes32 _overlay,
        uint8 _depth,
        bytes32 _hash,
        bytes32 revealNonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_overlay, _depth, _hash, revealNonce));
    }

    /**
     * @notice Reveal the pre-image values used to generate commit provided during this round's commit phase.
     * @param _overlay The overlay address of the applicant.
     * @param _depth The reported depth.
     * @param _hash The reserve commitment hash.
     * @param _revealNonce The nonce used to generate the commit that is being revealed.
     */
    function reveal(
        bytes32 _overlay,
        uint8 _depth,
        bytes32 _hash,
        bytes32 _revealNonce
    ) external whenNotPaused {
        require(currentPhaseReveal(), "not in reveal phase");

        uint256 cr = currentRound();

        require(cr == currentCommitRound, "round received no commits");
        if (cr != currentRevealRound) {
            currentRevealRoundAnchor = currentRoundAnchor();
            delete currentReveals;
            currentRevealRound = cr;
            updateRandomness();
        }

        bytes32 commitHash = wrapCommit(_overlay, _depth, _hash, _revealNonce);

        uint256 commitsArrayLength = currentCommits.length;

        for (uint256 i = 0; i < commitsArrayLength; i++) {
            if (currentCommits[i].overlay == _overlay && commitHash == currentCommits[i].obfuscatedHash) {
                require(
                    inProximity(currentCommits[i].overlay, currentRevealRoundAnchor, _depth),
                    "anchor out of self reported depth"
                );
                //check can only revealed once
                require(currentCommits[i].revealed == false, "participant already revealed");
                currentCommits[i].revealed = true;
                currentCommits[i].revealIndex = currentReveals.length;

                currentReveals.push(
                    Reveal({
                        owner: currentCommits[i].owner,
                        overlay: currentCommits[i].overlay,
                        stake: currentCommits[i].stake,
                        stakeDensity: currentCommits[i].stake * uint256(2**_depth),
                        hash: _hash,
                        depth: _depth
                    })
                );

                nonceBasedRandomness(_revealNonce);

                emit Revealed(
                    cr,
                    currentCommits[i].overlay,
                    currentCommits[i].stake,
                    currentCommits[i].stake * uint256(2**_depth),
                    _hash,
                    _depth
                );

                return;
            }
        }

        require(false, "no matching commit or hash");
    }

    /**
     * @notice Determine if a the owner of a given overlay will be the beneficiary of the claim phase.
     * @param _overlay The overlay address of the applicant.
     */
    function isWinner(bytes32 _overlay) public view returns (bool) {
        require(currentPhaseClaim(), "winner not determined yet");

        uint256 cr = currentRound();

        require(cr == currentRevealRound, "round received no reveals");
        require(cr > currentClaimRound, "round already received successful claim");

        string memory truthSelectionAnchor = currentTruthSelectionAnchor();

        uint256 currentSum;
        uint256 currentWinnerSelectionSum;
        bytes32 winnerIs;
        bytes32 randomNumber;

        bytes32 truthRevealedHash;
        uint8 truthRevealedDepth;

        uint256 commitsArrayLength = currentCommits.length;

        uint256 revIndex;
        uint256 k = 0;

        for (uint256 i = 0; i < commitsArrayLength; i++) {
            if (currentCommits[i].revealed) {
                revIndex = currentCommits[i].revealIndex;
                currentSum += currentReveals[revIndex].stakeDensity;
                randomNumber = keccak256(abi.encodePacked(truthSelectionAnchor, k));

                if (uint256(randomNumber & MaxH) * currentSum < currentReveals[revIndex].stakeDensity * (uint256(MaxH) + 1)) {
                    truthRevealedHash = currentReveals[revIndex].hash;
                    truthRevealedDepth = currentReveals[revIndex].depth;
                }

                k++;
            }
        }

        k = 0;

        string memory winnerSelectionAnchor = currentWinnerSelectionAnchor();

        for (uint256 i = 0; i < commitsArrayLength; i++) {
            revIndex = currentCommits[i].revealIndex;
            if (currentCommits[i].revealed && truthRevealedHash == currentReveals[revIndex].hash && truthRevealedDepth == currentReveals[revIndex].depth) {
                currentWinnerSelectionSum += currentReveals[revIndex].stakeDensity;
                randomNumber = keccak256(abi.encodePacked(winnerSelectionAnchor, k));

                if (
                    uint256(randomNumber & MaxH) * currentWinnerSelectionSum < currentReveals[revIndex].stakeDensity * (uint256(MaxH) + 1)
                ) {
                    winnerIs = currentReveals[revIndex].overlay;
                }

                k++;
            }
        }

        return (winnerIs == _overlay);
    }
    /**
     * @notice Determine if a the owner of a given overlay can participate in the upcoming round.
     * @param overlay The overlay address of the applicant.
     * @param depth The storage depth the applicant intends to report.
     */
    function isParticipatingInUpcomingRound(bytes32 overlay, uint8 depth) public view returns (bool) {
        require(currentPhaseClaim() || currentPhaseCommit(), "not determined for upcoming round yet");
        require(
            Stakes.lastUpdatedBlockNumberOfOverlay(overlay) < block.number - 2 * roundLength,
            "stake updated recently"
        );
        require(Stakes.stakeOfOverlay(overlay) >= minimumStake, "stake amount does not meet minimum");
        return inProximity(overlay, currentRoundAnchor(), depth);
    }

    /**
     * @notice The random value used to choose the selected truth teller.
     */
    function currentTruthSelectionAnchor() private view returns (string memory) {
        require(currentPhaseClaim(), "not determined for current round yet");
        uint256 cr = currentRound();
        require(cr == currentRevealRound, "round received no reveals");

        return string(abi.encodePacked(seed, "0"));
    }

    /**
     * @notice The random value used to choose the selected beneficiary.
     */
    function currentWinnerSelectionAnchor() private view returns (string memory) {
        require(currentPhaseClaim(), "not determined for current round yet");
        uint256 cr = currentRound();
        require(cr == currentRevealRound, "round received no reveals");

        return string(abi.encodePacked(seed, "1"));
    }

    /**
     * @notice The anchor used to determine eligibility for the current round.
     * @dev A node must be within proximity order of less than or equal to the storage depth they intend to report.
     */
    function currentRoundAnchor() public view returns (bytes32 returnVal) {
        uint256 cr = currentRound();

        if (currentPhaseCommit() || (cr > currentRevealRound && !currentPhaseClaim())) {
            return currentSeed();
        }

        if (currentPhaseReveal() && cr == currentRevealRound) {
            require(false, "can't return value after first reveal");
        }

        if (currentPhaseClaim()) {
            return nextSeed();
        }
    }

    /**
     * @notice Conclude the current round by identifying the selected truth teller and beneficiary.
     * @dev
     */
    function claim() external whenNotPaused {
        require(currentPhaseClaim(), "not in claim phase");

        uint256 cr = currentRound();

        require(cr == currentRevealRound, "round received no reveals");
        require(cr > currentClaimRound, "round already received successful claim");

        string memory truthSelectionAnchor = currentTruthSelectionAnchor();

        uint256 currentSum;
        uint256 currentWinnerSelectionSum;
        bytes32 randomNumber;
        uint256 randomNumberTrunc;

        bytes32 truthRevealedHash;
        uint8 truthRevealedDepth;

        uint256 commitsArrayLength = currentCommits.length;
        uint256 revealsArrayLength = currentReveals.length;

        emit CountCommits(commitsArrayLength);
        emit CountReveals(revealsArrayLength);

        uint256 revIndex;
        uint256 k = 0;

        for (uint256 i = 0; i < commitsArrayLength; i++) {
            if (currentCommits[i].revealed) {
                revIndex = currentCommits[i].revealIndex;
                currentSum += currentReveals[revIndex].stakeDensity;
                randomNumber = keccak256(abi.encodePacked(truthSelectionAnchor, k));

                randomNumberTrunc = uint256(randomNumber & MaxH);

                // question is whether randomNumber / MaxH < probability
                // where probability is stakeDensity / currentSum
                // to avoid resorting to floating points all divisions should be
                // simplified with multiplying both sides (as long as divisor > 0)
                // randomNumber / (MaxH + 1) < stakeDensity / currentSum
                // ( randomNumber / (MaxH + 1) ) * currentSum < stakeDensity
                // randomNumber * currentSum < stakeDensity * (MaxH + 1)
                if (randomNumberTrunc * currentSum < currentReveals[revIndex].stakeDensity * (uint256(MaxH) + 1)) {
                    truthRevealedHash = currentReveals[revIndex].hash;
                    truthRevealedDepth = currentReveals[revIndex].depth;
                }

                k++;
            }
        }

        emit TruthSelected(truthRevealedHash, truthRevealedDepth);

        k = 0;

        string memory winnerSelectionAnchor = currentWinnerSelectionAnchor();

        for (uint256 i = 0; i < commitsArrayLength; i++) {
            revIndex = currentCommits[i].revealIndex;
            if (currentCommits[i].revealed ) {
               if ( truthRevealedHash == currentReveals[revIndex].hash && truthRevealedDepth == currentReveals[revIndex].depth) {
                    currentWinnerSelectionSum += currentReveals[revIndex].stakeDensity;
                    randomNumber = keccak256(abi.encodePacked(winnerSelectionAnchor, k));

                    randomNumberTrunc = uint256(randomNumber & MaxH);

                    if (
                        randomNumberTrunc * currentWinnerSelectionSum < currentReveals[revIndex].stakeDensity * (uint256(MaxH) + 1)
                    ) {
                        winner = currentReveals[revIndex];
                    }

                    k++;
                } else {
                    Stakes.freezeDeposit(currentReveals[revIndex].overlay, penaltyMultiplierDisagreement * roundLength * uint256(2**truthRevealedDepth));
                    // slash ph5
                }
            } else {
                // slash in later phase
                // Stakes.slashDeposit(currentCommits[i].overlay, currentCommits[i].stake);
                Stakes.freezeDeposit(currentCommits[i].overlay, penaltyMultiplierNonRevealed * roundLength * uint256(2**truthRevealedDepth));
                continue;
            }
        }

        emit WinnerSelected(winner);

        PostageContract.withdraw(winner.owner);

        OracleContract.adjustPrice(uint256(k));

        currentClaimRound = cr;
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./OrderStatisticsTree/HitchensOrderStatisticsTreeLib.sol";

/**
 * @title PostageStamp contract
 * @author The Swarm Authors
 * @dev The postage stamp contracts allows users to create and manage postage stamp batches.
 * The current balance for each batch is stored ordered in descending order of normalised balance.
 * Balance is normalised to be per chunk and the total spend since the contract was deployed, i.e. when a batch
 * is bought, its per-chunk balance is supplemented with the current cost of storing one chunk since the beginning of time,
 * as if the batch had existed since the contract's inception. During the _expiry_ process, each of these balances is
 * checked against the _currentTotalOutPayment_, a similarly normalised figure that represents the current cost of
 * storing one chunk since the beginning of time. A batch with a normalised balance less than _currentTotalOutPayment_
 * is treated as expired.
 *
 * The _currentTotalOutPayment_ is calculated using _totalOutPayment_ which is updated during _setPrice_ events so
 * that the applicable per-chunk prices can be charged for the relevant periods of time. This can then be multiplied
 * by the amount of chunks which are allowed to be stamped by each batch to get the actual cost of storage.
 *
 * The amount of chunks a batch can stamp is determined by the _bucketDepth_. A batch may store a maximum of 2^depth chunks.
 * The global figure for the currently allowed chunks is tracked by _validChunkCount_ and updated during batch _expiry_ events.
 */

contract PostageStamp is AccessControl, Pausable {
    using HitchensOrderStatisticsTreeLib for HitchensOrderStatisticsTreeLib.Tree;

    /**
     * @dev Emitted when a new batch is created.
     */
    event BatchCreated(
        bytes32 indexed batchId,
        uint256 totalAmount,
        uint256 normalisedBalance,
        address owner,
        uint8 depth,
        uint8 bucketDepth,
        bool immutableFlag
    );

    /**
     * @dev Emitted when an existing batch is topped up.
     */
    event BatchTopUp(bytes32 indexed batchId, uint256 topupAmount, uint256 normalisedBalance);

    /**
     * @dev Emitted when the depth of an existing batch increases.
     */
    event BatchDepthIncrease(bytes32 indexed batchId, uint8 newDepth, uint256 normalisedBalance);

    /**
     *@dev Emitted on every price update.
     */
    event PriceUpdate(uint256 price);

    struct Batch {
        // Owner of this batch (0 if not valid).
        address owner;
        // Current depth of this batch.
        uint8 depth;
        // Whether this batch is immutable.
        bool immutableFlag;
        // Normalised balance per chunk.
        uint256 normalisedBalance;
    }

    // Role allowed to increase totalOutPayment.
    bytes32 public constant PRICE_ORACLE_ROLE = keccak256("PRICE_ORACLE");
    // Role allowed to pause
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // Role allowed to withdraw the pot.
    bytes32 public constant REDISTRIBUTOR_ROLE = keccak256("REDISTRIBUTOR_ROLE");

    // Associate every batch id with batch data.
    mapping(bytes32 => Batch) public batches;
    // Store every batch id ordered by normalisedBalance.
    HitchensOrderStatisticsTreeLib.Tree tree;

    // Address of the ERC20 token this contract references.
    address public bzzToken;

    // Total out payment per chunk, at the blockheight of the last price change.
    uint256 private totalOutPayment;

    // Minimum allowed depth of bucket.
    uint8 public minimumBucketDepth;

    // Combined global chunk capacity of valid batches remaining at the blockheight expire() was last called.
    uint256 public validChunkCount;

    // Lottery pot at last update.
    uint256 public pot;

    // Price from the last update.
    uint256 public lastPrice = 0;
    // Block at which the last update occured.
    uint256 public lastUpdatedBlock;
    // Normalised balance at the blockheight expire() was last called.
    uint256 public lastExpiryBalance;

    /**
     * @param _bzzToken The ERC20 token address to reference in this contract.
     * @param _minimumBucketDepth The minimum bucket depth of batches that can be purchased.
     */
    constructor(address _bzzToken, uint8 _minimumBucketDepth) {
        bzzToken = _bzzToken;
        minimumBucketDepth = _minimumBucketDepth;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @notice Create a new batch.
     * @dev At least `_initialBalancePerChunk*2^depth` tokens must be approved in the ERC20 token contract.
     * @param _owner Owner of the new batch.
     * @param _initialBalancePerChunk Initial balance per chunk.
     * @param _depth Initial depth of the new batch.
     * @param _nonce A random value used in the batch id derivation to allow multiple batches per owner.
     * @param _immutable Whether the batch is mutable.
     */
    function createBatch(
        address _owner,
        uint256 _initialBalancePerChunk,
        uint8 _depth,
        uint8 _bucketDepth,
        bytes32 _nonce,
        bool _immutable
    ) external whenNotPaused {
        require(_owner != address(0), "owner cannot be the zero address");
        // bucket depth should be non-zero and smaller than the depth
        require(_bucketDepth != 0 && minimumBucketDepth <= _bucketDepth && _bucketDepth < _depth, "invalid bucket depth");
        // derive batchId from msg.sender to ensure another party cannot use the same batch id and frontrun us.
        bytes32 batchId = keccak256(abi.encode(msg.sender, _nonce));
        require(batches[batchId].owner == address(0), "batch already exists");

        // per chunk balance multiplied by the batch size in chunks must be transferred from the sender
        uint256 totalAmount = _initialBalancePerChunk * (1 << _depth);
        require(ERC20(bzzToken).transferFrom(msg.sender, address(this), totalAmount), "failed transfer");

        // normalisedBalance is an absolute value per chunk, as if the batch had existed
        // since the block the contract was deployed, so we must supplement this batch's
        // _initialBalancePerChunk with the currentTotalOutPayment()
        uint256 normalisedBalance = currentTotalOutPayment() + (_initialBalancePerChunk);

        //update validChunkCount to remove currently expired batches
        expireLimited(type(uint256).max);

        //then add the chunks this batch will contribute
        validChunkCount += 1 << _depth;

        batches[batchId] = Batch({
            owner: _owner,
            depth: _depth,
            immutableFlag: _immutable,
            normalisedBalance: normalisedBalance
        });

        require(normalisedBalance > 0, "normalisedBalance cannot be zero");

        // insert into the ordered tree
        tree.insert(batchId, normalisedBalance);

        emit BatchCreated(batchId, totalAmount, normalisedBalance, _owner, _depth, _bucketDepth, _immutable);
    }

    /**
     * @notice Manually create a new batch when faciliatating migration, can only be called by the Admin role.
     * @dev At least `_initialBalancePerChunk*2^depth` tokens must be approved in the ERC20 token contract.
     * @param _owner Owner of the new batch.
     * @param _initialBalancePerChunk Initial balance per chunk of the batch.
     * @param _depth Initial depth of the new batch.
     * @param _batchId BatchId being copied (from previous version contract data).
     * @param _immutable Whether the batch is mutable.
     */
    function copyBatch(
        address _owner,
        uint256 _initialBalancePerChunk,
        uint8 _depth,
        uint8 _bucketDepth,
        bytes32 _batchId,
        bool _immutable
    ) external whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "only administrator can use copy method");
        require(_owner != address(0), "owner cannot be the zero address");
        require(_bucketDepth != 0 && _bucketDepth < _depth, "invalid bucket depth");
        require(batches[_batchId].owner == address(0), "batch already exists");

        // per chunk balance multiplied by the batch size in chunks must be transferred from the sender
        uint256 totalAmount = _initialBalancePerChunk * (1 << _depth);
        require(ERC20(bzzToken).transferFrom(msg.sender, address(this), totalAmount), "failed transfer");

        uint256 normalisedBalance = currentTotalOutPayment() + (_initialBalancePerChunk);

        validChunkCount += 1 << _depth;

        batches[_batchId] = Batch({
            owner: _owner,
            depth: _depth,
            immutableFlag: _immutable,
            normalisedBalance: normalisedBalance
        });

        require(normalisedBalance > 0, "normalisedBalance cannot be zero");

        tree.insert(_batchId, normalisedBalance);

        emit BatchCreated(_batchId, totalAmount, normalisedBalance, _owner, _depth, _bucketDepth, _immutable);
    }

    /**
     * @notice Top up an existing batch.
     * @dev At least `_topupAmountPerChunk*2^depth` tokens must be approved in the ERC20 token contract.
     * @param _batchId The id of an existing batch.
     * @param _topupAmountPerChunk The amount of additional tokens to add per chunk.
     */
    function topUp(bytes32 _batchId, uint256 _topupAmountPerChunk) external whenNotPaused {
        Batch storage batch = batches[_batchId];
        require(batch.owner != address(0), "batch does not exist or has expired");
        require(batch.normalisedBalance > currentTotalOutPayment(), "batch already expired");
        require(batch.depth > minimumBucketDepth, "batch too small to renew");

        // per chunk balance multiplied by the batch size in chunks must be transferred from the sender
        uint256 totalAmount = _topupAmountPerChunk * (1 << batch.depth);
        require(ERC20(bzzToken).transferFrom(msg.sender, address(this), totalAmount), "failed transfer");

        // update by removing batch and then reinserting
        tree.remove(_batchId, batch.normalisedBalance);
        batch.normalisedBalance = batch.normalisedBalance + (_topupAmountPerChunk);
        tree.insert(_batchId, batch.normalisedBalance);

        emit BatchTopUp(_batchId, totalAmount, batch.normalisedBalance);
    }

    /**
     * @notice Increase the depth of an existing batch.
     * @dev Can only be called by the owner of the batch.
     * @param _batchId the id of an existing batch.
     * @param _newDepth the new (larger than the previous one) depth for this batch.
     */
    function increaseDepth(bytes32 _batchId, uint8 _newDepth) external whenNotPaused {
        Batch storage batch = batches[_batchId];

        require(batch.owner == msg.sender, "not batch owner");
        require(minimumBucketDepth < _newDepth && batch.depth < _newDepth, "depth not increasing");
        require(!batch.immutableFlag, "batch is immutable");
        require(batch.normalisedBalance > currentTotalOutPayment(), "batch already expired");

        uint8 depthChange = _newDepth - batch.depth;
        // divide by the change in batch size (2^depthChange)
        uint256 newRemainingBalance = remainingBalance(_batchId) / (1 << depthChange);

        // expire batches up to current block before amending validChunkCount to include
        // the new chunks resultant of the depth increase
        expireLimited(type(uint256).max);
        validChunkCount += (1 << _newDepth) - (1 << batch.depth);

        // update by removing batch and then reinserting
        tree.remove(_batchId, batch.normalisedBalance);
        batch.depth = _newDepth;
        batch.normalisedBalance = currentTotalOutPayment() + (newRemainingBalance);
        tree.insert(_batchId, batch.normalisedBalance);

        emit BatchDepthIncrease(_batchId, _newDepth, batch.normalisedBalance);
    }

    /**
     * @notice Return the per chunk balance not yet used up.
     * @param _batchId The id of an existing batch.
     */
    function remainingBalance(bytes32 _batchId) public view returns (uint256) {
        Batch storage batch = batches[_batchId];
        require(batch.owner != address(0), "batch does not exist or expired");
        if (batch.normalisedBalance <= currentTotalOutPayment()) {
            return 0;
        }
        return batch.normalisedBalance - currentTotalOutPayment();
    }

    /**
     * @notice Set a new price.
     * @dev Can only be called by the price oracle role.
     * @param _price The new price.
     */
    function setPrice(uint256 _price) external {
        require(hasRole(PRICE_ORACLE_ROLE, msg.sender), "only price oracle can set the price");

        // if there was a last price, add the outpayment since the last update
        // using the last price to _totalOutPayment_. if there was not a lastPrice,
        // the lastprice must have been zero.
        if (lastPrice != 0) {
            totalOutPayment = currentTotalOutPayment();
        }

        lastPrice = _price;
        lastUpdatedBlock = block.number;

        emit PriceUpdate(_price);
    }

    /**
     * @notice Total per-chunk cost since the contract's deployment.
     * @dev Returns the total normalised all-time per chunk payout.
     * Only Batches with a normalised balance greater than this are valid.
     */
    function currentTotalOutPayment() public view returns (uint256) {
        uint256 blocks = block.number - lastUpdatedBlock;
        uint256 increaseSinceLastUpdate = lastPrice * (blocks);
        return totalOutPayment + (increaseSinceLastUpdate);
    }

    /**
     * @notice Pause the contract.
     * @dev Can only be called by the pauser when not paused.
     * The contract can be provably stopped by renouncing the pauser role and the admin role once paused.
     */
    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "only pauser can pause");
        _pause();
    }

    /**
     * @notice Unpause the contract.
     * @dev Can only be called by the pauser role while paused.
     */
    function unPause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "only pauser can unpause");
        _unpause();
    }

    /**
     * @notice Return true if no batches exist
     */
    function empty() public view returns (bool) {
        return tree.count() == 0;
    }

    /**
     * @notice Get the first batch id ordered by ascending normalised balance.
     * @dev If more than one batch id, return index at 0, if no batches, revert.
     */
    function firstBatchId() public view returns (bytes32) {
        uint256 val = tree.first();
        require(val > 0, "no batches exist");
        return tree.valueKeyAtIndex(val, 0);
    }

    /**
     * @notice Reclaims a limited number of expired batches
     * @dev Can be used if reclaiming all expired batches would exceed the block gas limit, causing other
     * contract method calls to fail.
     * @param limit The maximum number of batches to expire.
     */
    function expireLimited(uint256 limit) public {
        // the lower bound of the normalised balance for which we will check if batches have expired
        uint256 leb = lastExpiryBalance;
        uint256 i;
        for (i = 0; i < limit; i++) {
            if (empty()) {
                lastExpiryBalance = currentTotalOutPayment();
                break;
            }
            // get the batch with the smallest normalised balance
            bytes32 fbi = firstBatchId();
            // if the batch with the smallest balance has not yet expired
            // we have already reached the end of the batches we need
            // to expire, so exit the loop
            if (remainingBalance(fbi) > 0) {
                // the upper bound of the normalised balance for which we will check if batches have expired
                // value is updated when there are no expired batches left
                lastExpiryBalance = currentTotalOutPayment();
                break;
            }
            // otherwise, the batch with the smallest balance has expired,
            // so we must remove the chunks this batch contributes to the global validChunkCount
            Batch storage batch = batches[fbi];
            uint256 batchSize = 1 << batch.depth;
            require(validChunkCount >= batchSize , "insufficient valid chunk count");
            validChunkCount -= batchSize;
            // since the batch expired _during_ the period we must add
            // remaining normalised payout for this batch only
            pot += batchSize * (batch.normalisedBalance - leb);
            tree.remove(fbi, batch.normalisedBalance);
            delete batches[fbi];
        }
        // then, for all batches that have _not_ expired during the period
        // add the total normalised payout of all batches
        // multiplied by the remaining total valid chunk count
        // to the pot for the period since the last expiry

        require(lastExpiryBalance >= leb, "current total outpayment should never decrease");

        // then, for all batches that have _not_ expired during the period
        // add the total normalised payout of all batches
        // multiplied by the remaining total valid chunk count
        // to the pot for the period since the last expiry
        pot += validChunkCount * (lastExpiryBalance - leb);
    }

    /**
     * @notice Indicates whether expired batches exist.
     */
    function expiredBatchesExist() public view returns (bool) {
        if (empty()){
            return false;
        }
        return (remainingBalance(firstBatchId()) <= 0);
    }

    /**
     * @notice The current pot.
     */
    function totalPot() public returns (uint256) {
        expireLimited(type(uint256).max);
        uint256 balance = ERC20(bzzToken).balanceOf(address(this));
        return pot < balance ? pot : balance;
    }

    /**
     * @notice Withdraw the pot, authorised callers only.
     * @param beneficiary Recieves the current total pot.
     */

    function withdraw(address beneficiary) external {
        require(hasRole(REDISTRIBUTOR_ROLE, msg.sender), "only redistributor can withdraw from the contract");
        require(ERC20(bzzToken).transfer(beneficiary, totalPot()), "failed transfer");
        pot = 0;
    }

    /**
     * @notice Topup the pot.
     * @param amount Amount of tokens the pot will be topped up by.
     */
    function topupPot(uint256 amount) external {
        require(ERC20(bzzToken).transferFrom(msg.sender, address(this), amount), "failed transfer");
        pot += amount;
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./PostageStamp.sol";

/**
 * @title PriceOracle contract.
 * @author The Swarm Authors.
 * @dev The price oracle contract emits a price feed using events.
 */
contract PriceOracle is AccessControl {
    /**
     *@dev Emitted on every price update.
     */
    event PriceUpdate(uint256 price);

    // Role allowed to update price
    bytes32 public constant PRICE_UPDATER_ROLE = keccak256("PRICE_UPDATER");

    // The minimum price allowed
    uint256 public constant minimumPrice = 1024;

    // The current price is the atomic unit.
    uint256 public currentPrice = minimumPrice;

    // Constants used to modulate the price, see below usage
    uint256[] public increaseRate = [0, 1069, 1048, 1032, 1024, 1021, 1015, 1003, 980];

    uint16 targetRedundancy = 4;
    uint16 maxConsideredExtraRedundancy = 4;

    // When the contract is paused, price changes are not effective
    bool public isPaused = true;

    // The address of the linked PostageStamp contract
    PostageStamp public postageStamp;

    constructor(address _postageStamp) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        postageStamp = PostageStamp(_postageStamp);
    }

    /**
     * @notice Manually set the price.
     * @dev Can only be called by the admin role.
     * @param _price The new price.
     */
    function setPrice(uint256 _price) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is not the admin");
        currentPrice = _price;

        //enforce minimum price
        if (currentPrice < minimumPrice) {
            currentPrice = minimumPrice;
        }

        postageStamp.setPrice(currentPrice);
        emit PriceUpdate(currentPrice);
    }

    /**
     * @notice Pause the contract.
     * @dev Can only be called by the admin role.
     */
    function pause() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is not the admin");
        isPaused = true;
    }

    /**
     * @notice Unpause the contract.
     * @dev Can only be called by the admin role.
     */
    function unPause() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is not the admin");
        isPaused = false;
    }

    /**
     * @notice Automatically adjusts the price, called from the Redistribution contract
     * @dev The ideal redundancy in Swarm is 4 nodes per neighbourhood. Each round, the
     * Redistribution contract reports the current amount of nodes in the neighbourhood
     * who have commited and revealed truthy reserve commitment hashes, this is called
     * the redundancy signal. The target redundancy is 4, so, if the redundancy signal is 4,
     * no action is taken. If the redundancy signal is greater than 4, i.e. there is extra
     * redundancy, a price decrease is applied in order to reduce the incentive to run a node.
     * If the redundancy signal is less than 4, a price increase is applied in order to
     * increase the incentive to run a node. If the redundancy signal is more than 8, we
     * apply the max price decrease as if there were just four extra nodes.
     *
     * Can only be called by the price updater role, this should be set to be the deployed
     * Redistribution contract's address. Rounds down to return an integer.
     */
    function adjustPrice(uint256 redundancy) external {
        if (isPaused == false) {
            require(hasRole(PRICE_UPDATER_ROLE, msg.sender), "caller is not a price updater");

            uint256 multiplier = minimumPrice;
            uint256 usedRedundancy = redundancy;

            // redundancy may not be zero
            require(redundancy > 0, "unexpected zero");

            // enforce maximum considered extra redundancy
            uint16 maxConsideredRedundancy = targetRedundancy + maxConsideredExtraRedundancy;
            if (redundancy > maxConsideredRedundancy) {
                usedRedundancy = maxConsideredRedundancy;
            }

            // use the increaseRate array of constants to determine
            // the rate at which the price will modulate - if usedRedundancy
            // is the target value 4 there is no change, > 4 causes an increase
            // and < 4 a decrease.
            uint256 ir = increaseRate[usedRedundancy];

            // the multiplier is used to ensure whole number
            currentPrice = (ir * currentPrice) / multiplier;

            //enforce minimum price
            if (currentPrice < minimumPrice) {
                currentPrice = minimumPrice;
            }

            postageStamp.setPrice(currentPrice);
            emit PriceUpdate(currentPrice);
        }
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Staking contract for the Swarm storage incentives
 * @author The Swarm Authors
 * @dev Allows users to stake tokens in order to be eligible for the Redistribution Schelling co-ordination game.
 * Stakes are not withdrawable unless the contract is paused, e.g. in the event of migration to a new staking
 * contract. Stakes are frozen or slashed by the Redistribution contract in response to violations of the
 * protocol.
 */

contract StakeRegistry is AccessControl, Pausable {
    /**
     * @dev Emitted when a stake is created or updated by `owner` of the `overlay` by `stakeamount`, during `lastUpdatedBlock`.
     */
    event StakeUpdated(bytes32 indexed overlay, uint256 stakeAmount, address owner, uint256 lastUpdatedBlock);

    /**
     * @dev Emitted when a stake for overlay `slashed` is slashed by `amount`.
     */
    event StakeSlashed(bytes32 slashed, uint256 amount);

    /**
     * @dev Emitted when a stake for overlay `frozen` for `time` blocks.
     */
    event StakeFrozen(bytes32 slashed, uint256 time);

    struct Stake {
        // Overlay of the node that is being staked
        bytes32 overlay;
        // Amount of tokens staked
        uint256 stakeAmount;
        // Owner of `overlay`
        address owner;
        // Block height the stake was updated
        uint256 lastUpdatedBlockNumber;
        // Used to indicate presents in stakes struct
        bool isValue;
    }

    // Associate every stake id with overlay data.
    mapping(bytes32 => Stake) public stakes;

    // Role allowed to pause
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // Role allowed to freeze and slash entries
    bytes32 public constant REDISTRIBUTOR_ROLE = keccak256("REDISTRIBUTOR_ROLE");

    // Swarm network ID
    uint64 NetworkId;

    // Address of the staked ERC20 token
    address public bzzToken;

    /**
     * @param _bzzToken Address of the staked ERC20 token
     * @param _NetworkId Swarm network ID
     */
    constructor(address _bzzToken, uint64 _NetworkId) {
        NetworkId = _NetworkId;
        bzzToken = _bzzToken;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Checks to see if `overlay` is frozen.
     * @param overlay Overlay of staked overlay
     *
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function overlayNotFrozen(bytes32 overlay) internal view returns (bool) {
        return stakes[overlay].lastUpdatedBlockNumber < block.number;
    }

    /**
     * @dev Returns the current `stakeAmount` of `overlay`.
     * @param overlay Overlay of node
     */
    function stakeOfOverlay(bytes32 overlay) public view returns (uint256) {
        return stakes[overlay].stakeAmount;
    }

    /**
     * @dev Returns the current usable `stakeAmount` of `overlay`.
     * Checks whether the stake is currently frozen.
     * @param overlay Overlay of node
     */
    function usableStakeOfOverlay(bytes32 overlay) public view returns (uint256) {
        return overlayNotFrozen(overlay) ? stakes[overlay].stakeAmount : 0;
    }

    /**
     * @dev Returns the `lastUpdatedBlockNumber` of `overlay`.
     */
    function lastUpdatedBlockNumberOfOverlay(bytes32 overlay) public view returns (uint256) {
        return stakes[overlay].lastUpdatedBlockNumber;
    }

    /**
     * @dev Returns the eth address of the owner of `overlay`.
     * @param overlay Overlay of node
     */
    function ownerOfOverlay(bytes32 overlay) public view returns (address) {
        return stakes[overlay].owner;
    }

    /**
     * @dev Please both Endians 🥚.
     * @param input Eth address used for overlay calculation.
     */
    function reverse(uint64 input) internal pure returns (uint64 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    /**
     * @notice Create a new stake or update an existing one.
     * @dev At least `_initialBalancePerChunk*2^depth` number of tokens need to be preapproved for this contract.
     * @param _owner Eth address used for overlay calculation.
     * @param nonce Nonce that was used for overlay calculation.
     * @param amount Deposited amount of ERC20 tokens.
     */
    function depositStake(
        address _owner,
        bytes32 nonce,
        uint256 amount
    ) external whenNotPaused {
        require(_owner == msg.sender, "only owner can update stake");

        bytes32 overlay = keccak256(abi.encodePacked(_owner, reverse(NetworkId), nonce));

        uint256 updatedAmount = amount;

        if (stakes[overlay].isValue) {
            require(overlayNotFrozen(overlay), "overlay currently frozen");
            updatedAmount = amount + stakes[overlay].stakeAmount;
        }

        require(ERC20(bzzToken).transferFrom(msg.sender, address(this), amount), "failed transfer");

        emit StakeUpdated(overlay, updatedAmount, _owner, block.number);

        stakes[overlay] = Stake({
            owner: _owner,
            overlay: overlay,
            stakeAmount: updatedAmount,
            lastUpdatedBlockNumber: block.number,
            isValue: true
        });
    }

    /**
     * @dev Withdraw stake only when the staking contract is paused,
     * can only be called by the owner specific to the associated `overlay`
     * @param overlay The overlay to withdraw from
     * @param amount The amount of ERC20 tokens to be withdrawn
     */
    function withdrawFromStake(bytes32 overlay, uint256 amount) external whenPaused {
        require(stakes[overlay].owner == msg.sender, "only owner can withdraw stake");
        uint256 withDrawLimit = amount;
        if (amount > stakes[overlay].stakeAmount) {
            withDrawLimit = stakes[overlay].stakeAmount;
        }

        if (withDrawLimit < stakes[overlay].stakeAmount) {
            stakes[overlay].stakeAmount -= withDrawLimit;
            stakes[overlay].lastUpdatedBlockNumber = block.number;
            require(ERC20(bzzToken).transfer(msg.sender, withDrawLimit), "failed withdrawal");
        } else {
            delete stakes[overlay];
            require(ERC20(bzzToken).transfer(msg.sender, withDrawLimit), "failed withdrawal");
        }
    }

    /**
     * @dev Freeze an existing stake, can only be called by the redistributor
     * @param overlay the overlay selected
     * @param time penalty length in blocknumbers
     */
    function freezeDeposit(bytes32 overlay, uint256 time) external {
        require(hasRole(REDISTRIBUTOR_ROLE, msg.sender), "only redistributor can freeze stake");

        if (stakes[overlay].isValue) {
            emit StakeFrozen(overlay, time);
            stakes[overlay].lastUpdatedBlockNumber = block.number + time;
        }
    }

    /**
     * @dev Slash an existing stake, can only be called by the `redistributor`
     * @param overlay the overlay selected
     * @param amount the amount to be slashed
     */
    function slashDeposit(bytes32 overlay, uint256 amount) external {
        require(hasRole(REDISTRIBUTOR_ROLE, msg.sender), "only redistributor can slash stake");
        emit StakeSlashed(overlay, amount);
        if (stakes[overlay].isValue) {
            if (stakes[overlay].stakeAmount > amount) {
                stakes[overlay].stakeAmount -= amount;
                stakes[overlay].lastUpdatedBlockNumber = block.number;
            } else {
                delete stakes[overlay];
            }
        }
    }

    /**
     * @dev Pause the contract. The contract is provably stopped by renouncing
     the pauser role and the admin role after pausing, can only be called by the `PAUSER`
     */
    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "only pauser can pause");
        _pause();
    }

    /**
     * @dev Unpause the contract, can only be called by the pauser when paused
     */
    function unPause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "only pauser can unpause");
        _unpause();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping (address => bool) members;
        bytes32 adminRole;
    }

    mapping (bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

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
     * bearer except when using {_setupRole}.
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
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
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
    function grantRole(bytes32 role, address account) public virtual override {
        require(hasRole(getRoleAdmin(role), _msgSender()), "AccessControl: sender must be an admin to grant");

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
    function revokeRole(bytes32 role, address account) public virtual override {
        require(hasRole(getRoleAdmin(role), _msgSender()), "AccessControl: sender must be an admin to revoke");

        _revokeRole(role, account);
    }

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
        emit RoleAdminChanged(role, getRoleAdmin(role), adminRole);
        _roles[role].adminRole = adminRole;
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT

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
    constructor () {
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
pragma solidity ^0.8.1;

/*
Hitchens Order Statistics Tree v0.99

A Solidity Red-Black Tree library to store and maintain a sorted data
structure in a Red-Black binary search tree, with O(log 2n) insert, remove
and search time (and gas, approximately)

https://github.com/rob-Hitchens/OrderStatisticsTree

Copyright (c) Rob Hitchens. the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Significant portions from BokkyPooBahsRedBlackTreeLibrary,
https://github.com/bokkypoobah/BokkyPooBahsRedBlackTreeLibrary

THIS SOFTWARE IS NOT TESTED OR AUDITED. DO NOT USE FOR PRODUCTION.
*/

library HitchensOrderStatisticsTreeLib {
    uint  private constant EMPTY = 0;
    struct Node {
        uint  parent;
        uint  left;
        uint  right;
        bool red;
        bytes32[] keys;
        mapping(bytes32 => uint ) keyMap;
        uint  count;
    }
    struct Tree {
        uint  root;
        mapping(uint  => Node) nodes;
    }

    function first(Tree storage self) internal view returns (uint  _value) {
        _value = self.root;
        if (_value == EMPTY) return 0;
        while (self.nodes[_value].left != EMPTY) {
            _value = self.nodes[_value].left;
        }
    }

    function exists(Tree storage self, uint  value) internal view returns (bool _exists) {
        if (value == EMPTY) return false;
        if (value == self.root) return true;
        if (self.nodes[value].parent != EMPTY) return true;
        return false;
    }

    function keyExists(
        Tree storage self,
        bytes32 key,
        uint  value
    ) internal view returns (bool _exists) {
        if (!exists(self, value)) return false;
        return self.nodes[value].keys[self.nodes[value].keyMap[key]] == key;
    }

    function getNode(Tree storage self, uint  value)
        internal
        view
        returns (
            uint  _parent,
            uint  _left,
            uint  _right,
            bool _red,
            uint  keyCount,
            uint  __count
        )
    {
        require(exists(self, value), "OrderStatisticsTree(403) - Value does not exist.");
        Node storage gn = self.nodes[value];
        return (gn.parent, gn.left, gn.right, gn.red, gn.keys.length, gn.keys.length + gn.count);
    }

    function getNodeCount(Tree storage self, uint  value) internal view returns (uint  __count) {
        Node storage gn = self.nodes[value];
        return gn.keys.length + gn.count;
    }

    function valueKeyAtIndex(
        Tree storage self,
        uint  value,
        uint  index
    ) internal view returns (bytes32 _key) {
        require(exists(self, value), "OrderStatisticsTree(404) - Value does not exist.");
        return self.nodes[value].keys[index];
    }

    function count(Tree storage self) internal view returns (uint  _count) {
        return getNodeCount(self, self.root);
    }

    /* We don't use this functionality, so it is commented out to make audit easier

    function percentile(Tree storage self, uint value) internal view returns(uint _percentile) {
        uint denominator = count(self);
        uint numerator = rank(self, value);
        _percentile = ((uint(1000) * numerator)/denominator+(uint(5)))/uint(10);
    }
    function permil(Tree storage self, uint value) internal view returns(uint _permil) {
        uint denominator = count(self);
        uint numerator = rank(self, value);
        _permil = ((uint(10000) * numerator)/denominator+(uint(5)))/uint(10);
    }
    function atPercentile(Tree storage self, uint _percentile) internal view returns(uint _value) {
        uint findRank = (((_percentile * count(self))/uint(10)) + uint(5)) / uint(10);
        return atRank(self,findRank);
    }
    function atPermil(Tree storage self, uint _permil) internal view returns(uint _value) {
        uint findRank = (((_permil * count(self))/uint(100)) + uint(5)) / uint(10);
        return atRank(self,findRank);
    }
    function median(Tree storage self) internal view returns(uint value) {
        return atPercentile(self,50);
    }
    function below(Tree storage self, uint value) public view returns(uint _below) {
        if(count(self) > 0 && value > 0) _below = rank(self,value)-uint(1);
    }
    function above(Tree storage self, uint value) public view returns(uint _above) {
        if(count(self) > 0) _above = count(self)-rank(self,value);
    }
    function valueBelowEstimate(Tree storage self, uint estimate) public view returns(uint _below) {
        if(count(self) > 0 && estimate > 0) {
            uint  highestValue = last(self);
            uint  lowestValue = first(self);
            if(estimate < lowestValue) {
                return 0;
            }
            if(estimate >= highestValue) {
                return highestValue;
            }
            uint  rankOfValue = rank(self, estimate); // approximation
            _below = atRank(self, rankOfValue);
            if(_below > estimate) { // fix error in approximation
                rankOfValue--;
                _below = atRank(self, rankOfValue);
            }
        }
    }
    function valueAboveEstimate(Tree storage self, uint estimate) public view returns(uint _above) {
        if(count(self) > 0 && estimate > 0) {
            uint  highestValue = last(self);
            uint  lowestValue = first(self);
            if(estimate > highestValue) {
                return 0;
            }
            if(estimate <= lowestValue) {
                return lowestValue;
            }
            uint  rankOfValue = rank(self, estimate); // approximation
            _above = atRank(self, rankOfValue);
            if(_above < estimate) { // fix error in approximation
                rankOfValue++;
                _above = atRank(self, rankOfValue);
            }
        }
    }
    function rank(Tree storage self, uint value) internal view returns(uint _rank) {
        if(count(self) > 0) {
            bool finished;
            uint cursor = self.root;
            Node storage c = self.nodes[cursor];
            uint smaller = getNodeCount(self,c.left);
            while (!finished) {
                uint keyCount = c.keys.length;
                if(cursor == value) {
                    finished = true;
                } else {
                    if(cursor < value) {
                        cursor = c.right;
                        c = self.nodes[cursor];
                        smaller += keyCount + getNodeCount(self,c.left);
                    } else {
                        cursor = c.left;
                        c = self.nodes[cursor];
                        smaller -= (keyCount + getNodeCount(self,c.right));
                    }
                }
                if (!exists(self,cursor)) {
                    finished = true;
                }
            }
            return smaller + 1;
        }
    }
    function atRank(Tree storage self, uint _rank) internal view returns(uint _value) {
        bool finished;
        uint cursor = self.root;
        Node storage c = self.nodes[cursor];
        uint smaller = getNodeCount(self,c.left);
        while (!finished) {
            _value = cursor;
            c = self.nodes[cursor];
            uint keyCount = c.keys.length;
            if(smaller + 1 >= _rank && smaller + keyCount <= _rank) {
                _value = cursor;
                finished = true;
            } else {
                if(smaller + keyCount <= _rank) {
                    cursor = c.right;
                    c = self.nodes[cursor];
                    smaller += keyCount + getNodeCount(self,c.left);
                } else {
                    cursor = c.left;
                    c = self.nodes[cursor];
                    smaller -= (keyCount + getNodeCount(self,c.right));
                }
            }
            if (!exists(self,cursor)) {
                finished = true;
            }
        }
    }
*/

    function insert(
        Tree storage self,
        bytes32 key,
        uint  value
    ) internal {
        require(value != EMPTY, "OrderStatisticsTree(405) - Value to insert cannot be zero");
        require(
            !keyExists(self, key, value),
            "OrderStatisticsTree(406) - Value and Key pair exists. Cannot be inserted again."
        );
        uint  cursor;
        uint  probe = self.root;
        while (probe != EMPTY) {
            cursor = probe;
            if (value < probe) {
                probe = self.nodes[probe].left;
            } else if (value > probe) {
                probe = self.nodes[probe].right;
            } else if (value == probe) {
                self.nodes[probe].keys.push(key);
                self.nodes[probe].keyMap[key] = self.nodes[probe].keys.length - uint (1);
                return;
            }
            self.nodes[cursor].count++;
        }
        Node storage nValue = self.nodes[value];
        nValue.parent = cursor;
        nValue.left = EMPTY;
        nValue.right = EMPTY;
        nValue.red = true;
        nValue.keys.push(key);
        nValue.keyMap[key] = nValue.keys.length - uint (1);
        if (cursor == EMPTY) {
            self.root = value;
        } else if (value < cursor) {
            self.nodes[cursor].left = value;
        } else {
            self.nodes[cursor].right = value;
        }
        insertFixup(self, value);
    }

    function remove(
        Tree storage self,
        bytes32 key,
        uint  value
    ) internal {
        require(value != EMPTY, "OrderStatisticsTree(407) - Value to delete cannot be zero");
        require(keyExists(self, key, value), "OrderStatisticsTree(408) - Value to delete does not exist.");
        Node storage nValue = self.nodes[value];
        uint  rowToDelete = nValue.keyMap[key];
        bytes32 last = nValue.keys[nValue.keys.length - uint (1)];
        nValue.keys[rowToDelete] = last;
        nValue.keyMap[last] = rowToDelete;
        nValue.keys.pop();
        uint  probe;
        uint  cursor;
        if (nValue.keys.length == 0) {
            if (self.nodes[value].left == EMPTY || self.nodes[value].right == EMPTY) {
                cursor = value;
            } else {
                cursor = self.nodes[value].right;
                while (self.nodes[cursor].left != EMPTY) {
                    cursor = self.nodes[cursor].left;
                }
            }
            if (self.nodes[cursor].left != EMPTY) {
                probe = self.nodes[cursor].left;
            } else {
                probe = self.nodes[cursor].right;
            }
            uint  cursorParent = self.nodes[cursor].parent;
            self.nodes[probe].parent = cursorParent;
            if (cursorParent != EMPTY) {
                if (cursor == self.nodes[cursorParent].left) {
                    self.nodes[cursorParent].left = probe;
                } else {
                    self.nodes[cursorParent].right = probe;
                }
            } else {
                self.root = probe;
            }
            bool doFixup = !self.nodes[cursor].red;
            if (cursor != value) {
                replaceParent(self, cursor, value);
                self.nodes[cursor].left = self.nodes[value].left;
                self.nodes[self.nodes[cursor].left].parent = cursor;
                self.nodes[cursor].right = self.nodes[value].right;
                self.nodes[self.nodes[cursor].right].parent = cursor;
                self.nodes[cursor].red = self.nodes[value].red;
                (cursor, value) = (value, cursor);
                fixCountRecurse(self, value);
            }
            if (doFixup) {
                removeFixup(self, probe);
            }
            fixCountRecurse(self, cursorParent);
            delete self.nodes[cursor];
        }
    }

    function fixCountRecurse(Tree storage self, uint  value) private {
        while (value != EMPTY) {
            self.nodes[value].count =
                getNodeCount(self, self.nodes[value].left) +
                getNodeCount(self, self.nodes[value].right);
            value = self.nodes[value].parent;
        }
    }

    function treeMinimum(Tree storage self, uint  value) private view returns (uint ) {
        while (self.nodes[value].left != EMPTY) {
            value = self.nodes[value].left;
        }
        return value;
    }

    function treeMaximum(Tree storage self, uint  value) private view returns (uint ) {
        while (self.nodes[value].right != EMPTY) {
            value = self.nodes[value].right;
        }
        return value;
    }

    function rotateLeft(Tree storage self, uint  value) private {
        uint  cursor = self.nodes[value].right;
        uint  parent = self.nodes[value].parent;
        uint  cursorLeft = self.nodes[cursor].left;
        self.nodes[value].right = cursorLeft;
        if (cursorLeft != EMPTY) {
            self.nodes[cursorLeft].parent = value;
        }
        self.nodes[cursor].parent = parent;
        if (parent == EMPTY) {
            self.root = cursor;
        } else if (value == self.nodes[parent].left) {
            self.nodes[parent].left = cursor;
        } else {
            self.nodes[parent].right = cursor;
        }
        self.nodes[cursor].left = value;
        self.nodes[value].parent = cursor;
        self.nodes[value].count =
            getNodeCount(self, self.nodes[value].left) +
            getNodeCount(self, self.nodes[value].right);
        self.nodes[cursor].count =
            getNodeCount(self, self.nodes[cursor].left) +
            getNodeCount(self, self.nodes[cursor].right);
    }

    function rotateRight(Tree storage self, uint  value) private {
        uint  cursor = self.nodes[value].left;
        uint  parent = self.nodes[value].parent;
        uint  cursorRight = self.nodes[cursor].right;
        self.nodes[value].left = cursorRight;
        if (cursorRight != EMPTY) {
            self.nodes[cursorRight].parent = value;
        }
        self.nodes[cursor].parent = parent;
        if (parent == EMPTY) {
            self.root = cursor;
        } else if (value == self.nodes[parent].right) {
            self.nodes[parent].right = cursor;
        } else {
            self.nodes[parent].left = cursor;
        }
        self.nodes[cursor].right = value;
        self.nodes[value].parent = cursor;
        self.nodes[value].count =
            getNodeCount(self, self.nodes[value].left) +
            getNodeCount(self, self.nodes[value].right);
        self.nodes[cursor].count =
            getNodeCount(self, self.nodes[cursor].left) +
            getNodeCount(self, self.nodes[cursor].right);
    }

    function insertFixup(Tree storage self, uint  value) private {
        uint  cursor;
        while (value != self.root && self.nodes[self.nodes[value].parent].red) {
            uint  valueParent = self.nodes[value].parent;
            if (valueParent == self.nodes[self.nodes[valueParent].parent].left) {
                cursor = self.nodes[self.nodes[valueParent].parent].right;
                if (self.nodes[cursor].red) {
                    self.nodes[valueParent].red = false;
                    self.nodes[cursor].red = false;
                    self.nodes[self.nodes[valueParent].parent].red = true;
                    value = self.nodes[valueParent].parent;
                } else {
                    if (value == self.nodes[valueParent].right) {
                        value = valueParent;
                        rotateLeft(self, value);
                    }
                    valueParent = self.nodes[value].parent;
                    self.nodes[valueParent].red = false;
                    self.nodes[self.nodes[valueParent].parent].red = true;
                    rotateRight(self, self.nodes[valueParent].parent);
                }
            } else {
                cursor = self.nodes[self.nodes[valueParent].parent].left;
                if (self.nodes[cursor].red) {
                    self.nodes[valueParent].red = false;
                    self.nodes[cursor].red = false;
                    self.nodes[self.nodes[valueParent].parent].red = true;
                    value = self.nodes[valueParent].parent;
                } else {
                    if (value == self.nodes[valueParent].left) {
                        value = valueParent;
                        rotateRight(self, value);
                    }
                    valueParent = self.nodes[value].parent;
                    self.nodes[valueParent].red = false;
                    self.nodes[self.nodes[valueParent].parent].red = true;
                    rotateLeft(self, self.nodes[valueParent].parent);
                }
            }
        }
        self.nodes[self.root].red = false;
    }

    function replaceParent(
        Tree storage self,
        uint  a,
        uint  b
    ) private {
        uint  bParent = self.nodes[b].parent;
        self.nodes[a].parent = bParent;
        if (bParent == EMPTY) {
            self.root = a;
        } else {
            if (b == self.nodes[bParent].left) {
                self.nodes[bParent].left = a;
            } else {
                self.nodes[bParent].right = a;
            }
        }
    }

    function removeFixup(Tree storage self, uint  value) private {
        uint  cursor;
        while (value != self.root && !self.nodes[value].red) {
            uint  valueParent = self.nodes[value].parent;
            if (value == self.nodes[valueParent].left) {
                cursor = self.nodes[valueParent].right;
                if (self.nodes[cursor].red) {
                    self.nodes[cursor].red = false;
                    self.nodes[valueParent].red = true;
                    rotateLeft(self, valueParent);
                    cursor = self.nodes[valueParent].right;
                }
                if (!self.nodes[self.nodes[cursor].left].red && !self.nodes[self.nodes[cursor].right].red) {
                    self.nodes[cursor].red = true;
                    value = valueParent;
                } else {
                    if (!self.nodes[self.nodes[cursor].right].red) {
                        self.nodes[self.nodes[cursor].left].red = false;
                        self.nodes[cursor].red = true;
                        rotateRight(self, cursor);
                        cursor = self.nodes[valueParent].right;
                    }
                    self.nodes[cursor].red = self.nodes[valueParent].red;
                    self.nodes[valueParent].red = false;
                    self.nodes[self.nodes[cursor].right].red = false;
                    rotateLeft(self, valueParent);
                    value = self.root;
                }
            } else {
                cursor = self.nodes[valueParent].left;
                if (self.nodes[cursor].red) {
                    self.nodes[cursor].red = false;
                    self.nodes[valueParent].red = true;
                    rotateRight(self, valueParent);
                    cursor = self.nodes[valueParent].left;
                }
                if (!self.nodes[self.nodes[cursor].right].red && !self.nodes[self.nodes[cursor].left].red) {
                    self.nodes[cursor].red = true;
                    value = valueParent;
                } else {
                    if (!self.nodes[self.nodes[cursor].left].red) {
                        self.nodes[self.nodes[cursor].right].red = false;
                        self.nodes[cursor].red = true;
                        rotateLeft(self, cursor);
                        cursor = self.nodes[valueParent].left;
                    }
                    self.nodes[cursor].red = self.nodes[valueParent].red;
                    self.nodes[valueParent].red = false;
                    self.nodes[self.nodes[cursor].left].red = false;
                    rotateRight(self, valueParent);
                    value = self.root;
                }
            }
        }
        self.nodes[value].red = false;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The defaut value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overloaded;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

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