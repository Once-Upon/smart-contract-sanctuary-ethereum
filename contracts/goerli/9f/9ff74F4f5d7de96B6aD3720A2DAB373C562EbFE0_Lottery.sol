// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * * ¿Qué vamos a crear?
 * ! Contrato de loteria inquebrantable
 * *1. Enter the lottery (paying some amount)
 * *2. Pick  a random winner (verificable random)
 * *3. Winner to be selected every X minutes --> completly automated
 *
 * * We are gonna to use CHAINLINK Oracle for the Randomness and automated execution of the smartcontract. The smartconract itself,
 * * has no randomness and need someone to execute the contract everytime.
 */
/**
 * !Orden ideal para contratos de solidity por convencion
 * *Pragma, Imports,Errors, Interfaces, Libraries, NatSPEC antes de -->Contracts
 */
//Imports

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

//errors
error Lottery__notEnough();
error Lottery__TransferFailed();
error Lottery__Closed();
error Lottery__UpKeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 LotteryState
);

/**
 * @title A sample of Lottery Contract
 * @author Alejandro Guindo
 * @notice This contract is for creating a untamperable Lottery for pick random winners.
 * @dev This smart contract implements ChainLink VRF v2 and AutomationCompatible
 */
contract Lottery is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /**
     * !Order por convencion para contratos:
     * * Type declarations, state variables, events, modifiers, functions
     */
    //Type Declarations
    //Con esto creamos un tipo de contrato con dos estados. Es igual a decir Uint256 0 = OPEN, 1 = CALCULATING
    enum LotteryState {
        OPEN,
        CALCULATING
    }

    //State Variables

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_COORDINATOR;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUESTCONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUMWORDS = 1;

    //State Variables Lottery

    address private s_recentWinner;
    //Creamos variable de tipo lotteryState llamada s_lotteryState
    LotteryState private s_lotteryState;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    //Events
    /**
     * !Convencion, se pone el nombre inverso de la function donde queremos aplicar el evento
     */
    event LotteryEnter(address indexed player);
    event RequestedLoterryWinner(uint256 indexed requestId);
    event WinnersList(address indexed winner);

    //Modifiers

    constructor(
        address vrfCoordinatorV2, //Contract Address
        uint256 entranceFee,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        //en el constructor, indicamos que variable de nombre s_lotteryState es igual a OPEN concretamente.
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    //Reveice/Fallback

    //Functions que queremos crear
    //------------------------------------------------------------------------------------------------------------------------------
    function enterLottery() public payable {
        // Debemos requerir que msg.value > que i_entranceFee que es el mínimo a pagar

        if (msg.value < i_entranceFee) {
            revert Lottery__notEnough();
        }

        //SOlo queremos que la gente pueda entrar si el estado del contrato es OPEN

        if (s_lotteryState != LotteryState.OPEN) revert Lottery__Closed();

        s_players.push(payable(msg.sender)); //Payable porque se debe poder pagar a estas cuentas luego.

        //EMIT para aplicar el EVENT
        emit LotteryEnter(msg.sender);
    }

    //-----------------------------------------------------------------------------------------------------------------------------
    // Creamos la CheckUpKeep, directamente de chainlink Docu. Esta la necesitamos para comprobar si ha pasado el tiempo
    // que queremos para que la function se ejecute sola.
    /**
     * @dev This is the function that the Chainlink Keeper nodes look for the `upkeepNeeded` to return a boolean true.
     * The following to true, is to find a new random number.
     * Condiciones que queremos apra que se ejecute el random number.
     * 1. Time Interval correcto.
     * 2. El contrato lottery debe tener al menos un jugador y dinero en el contrato
     * 3. La subscription de chainlink automation debe tener LINK suficiente para poder pagarse
     * 4. Teh lottery sohuld be in a "open " state. Cuando esperamos a que se ejecuten la busqueda de random number,
     *  no podemos permitir que alguien se una a la lottery en ese momento, por ello, creamos ENUMS OPEN state para evitar esto.
     * !NOTA: Una vez que upKeepNeeded es TRUE, el nodo offchain the chainlink va a ejecutar directametne PerformUpkeep
     */

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (s_lotteryState == LotteryState.OPEN);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    //-----------------------------------------------------------------------------------------------------------------------------
    //Dos cosas a completar. Request a random number y una vez que lo tengamos, hacer algo con ello. Por ello para un proceso vamos
    //a tener dos functions. Lo primera solo para el pick random number. La segunda para hacer algo con ello. Es mas seguro asi.
    //Nombres de las functions "copian" los nombres de las functions de VRFConsumerBaseV2.sol de Chainlink
    /**
     * !NOTA. Renamed with performUpkeep, porque es la funcion que el nodo de Chainlink va a buscar para ejecutar.
     * *Antes se llamaba pickRandomWinner
     */
    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        //Volvemos a validar por seguridad que checkUpKeep es TRUE
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }

        //En esta function queremos que el estado de la lottery sea CALCULATING, para que nadie pueda entrar
        s_lotteryState = LotteryState.CALCULATING;

        uint256 requestId = i_COORDINATOR.requestRandomWords(
            i_keyHash, //Max gas que vamos a aceptar para realizar el proceso
            i_subscriptionId,
            REQUESTCONFIRMATIONS,
            i_callbackGasLimit,
            NUMWORDS
        );
        emit RequestedLoterryWinner(requestId);
    }

    //Estos parametros los sacamos de copiar el contrato de chainlink. Ademas agregamos en el constructor la address vrfCoordinatorV2
    //para que funcione
    function fulfillRandomWords(
        uint256, /*requestId*/
        uint256[] memory randomWords
    ) internal override {
        //una vez tenemos el random number, de ese numero debemos reducirlo para que nos de un numero de 0 a 9 con el que escoger
        //a un random winner.

        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0); //Reseteando el array.

        //Justo despues de encontrar nuestro ganador, volvemos a abrir el estado de la lottry para que gente se pueda unir
        s_lotteryState = LotteryState.OPEN;

        //Reseteamos el timeStamp
        s_lastTimeStamp = block.timestamp;

        //Call
        // Call es el metodo utlizado hoy en dia. devuelve un Boolean
        (bool callSuccess, ) = recentWinner.call{value: address(this).balance}(
            ""
        );
        //Para más eficiencia de gas
        //require(callSuccess, "Call Failed");
        if (!callSuccess) revert Lottery__TransferFailed();

        emit WinnersList(recentWinner);
    }

    //-----------------------------------------------------------------------------------------------------------------------------
    //function automatedExecution() {}

    //-----------------------------------------------------------------------------------------------------------------------------

    //View/Pure Functions
    //Function para hacer publico el i_entraceFee, ya que originalmente la hemos hecho private para ahorrar Gas
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    //Function para hacer pública el address[]players, ya que originalmente la hemos hehco private para ahorrar Gas

    function getAddressPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    //Function para hacer pública el address recentWinner, ya que originalmente la hemos hehco private para ahorrar Gas

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    //Function para hacer pública y ver el LotteryState, ya que originalmente la hemos hehco private para ahorrar Gas

    function getLotteryState() public view returns (LotteryState) {
        return s_lotteryState;
    }

    //Function para hacer pública y ver el numero de randomWords, ya que originalmente la hemos hehco private para ahorrar Gas

    //PURE para constant variables. Ya que lo lee directamente de las variables.
    function getNumRandomWords() public pure returns (uint256) {
        return NUMWORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    //PURE para constant variables. Ya que lo lee directamente de las variables.
    function getRequestConfirmations() public pure returns (uint256) {
        return REQUESTCONFIRMATIONS;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AutomationBase.sol";
import "./interfaces/AutomationCompatibleInterface.sol";

abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AutomationBase {
  error OnlySimulatedBackend();

  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}