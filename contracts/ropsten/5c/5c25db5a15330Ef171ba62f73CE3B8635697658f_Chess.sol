//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

/// @title A blockchain record of epic chess games
/// @author A. Nonymous
/// @notice You can use this contract to create chess games and record every move. Even attach a stake to the game that will be transferred to the winner.
/// @dev Requires off-chain service to validate and sign the moves.
contract Chess {
  event GameCreated(uint gameId, bytes32 clientId, address black, address white, uint stake);
  event GameJoined(uint gameId, bytes32 clientId, address white);
  event GameCanceled(uint gameId, address canceledBy);
  event TurnTaken(uint gameId, bytes32 clientId, address player, string board, 
    string moveTo, uint8 gameOverState);
  event CheckMate(uint gameId, bytes32 clientId, address winner);
  event StaleMate(uint gameId, bytes32 clientId);
  event Draw(uint gameId, bytes32 clientId);
  event TipReceived(address sender, uint amount, string message);
  event GameMemoUpdated(uint gameId, address updatedBy, uint updatedAt, string memo );

  enum GameOverState { GameNotOver, CheckMate, StaleMate, Draw, Canceled }

  struct Game {
    uint amount;
    uint gameFee;
    uint turnTimeout;
    uint createdAt;
    uint updatedAt;
    uint memoUpdatedAt;
    GameOverState gameOverState;
    bool pendingJoin;
    bool fundsPaid;
    address payable black;
    address payable white;
    address payable winner;
    address payable canceledBy;
    address turn;
    address memoUpdatedBy;
    bytes32 clientId;
    string board;
    string lastMoveFrom;
    string lastMoveTo;
    string memo;
  }

  string constant DEFAULT_BOARD = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  uint    public  version = 1;
  address payable public  owner;
  address public  validator;
  address payable public  payee;
  uint    public  gameFeePct;
  uint    public  minStake;
  uint    public  minExpire;
  uint    public  maxExpire;
  uint    public  maxMemo;
  bool    public  open;
  bool    public  playing;
  Game[] games;

  modifier onlyOwner()
  {
    require(msg.sender == owner, 'Unauthorized');
    _;
  }

  modifier ifOpen()
  {
    require(open == true, 'Not open');
    _;
  }

  modifier ifPlaying()
  {
    require(playing == true, 'Not playing');
    _;
  }

  constructor() {
    owner       = payable(msg.sender);
    validator   = owner;
    payee       = owner;
    minStake    = 0; 
    gameFeePct  = 0;
    minExpire   = 3600;        /// 1 hour
    maxExpire   = 86400 * 365; /// 1 year
    maxMemo     = 280;
    open        = true;
    playing     = true;
  }

  //  Only Owner Methods 

  /// @dev Update the gameFeePct used for new games (Created after change).
  /// @param _gameFeePct The percentage (whole numbe) fee of game stakes for contract owner (0-100).
  function setGameFee(uint _gameFeePct) external onlyOwner {
    gameFeePct = _gameFeePct;
  }

  /// @dev Update the minStake used for new games (Created after change).
  /// @param _minStake Minimum stake allowed for new games, can be 0.
  function setMinStake(uint _minStake) external onlyOwner {
    minStake = _minStake;
  }

  /// @dev Update the mi/maxnExpire used for new games (Created after change).
  /// @param _minExpire Minimum seconds that a game creator can set for turn expirations. 
  /// @param _maxExpire Maximum seconds that a game creator can set for turn expirations. 
  function setMinExpire(uint _minExpire, uint _maxExpire) external onlyOwner {
    minExpire = _minExpire;
    maxExpire = _maxExpire;
  }
  
  /// @dev Update the maxMemo used to control size allowed for game memos.
  /// @param _maxMemo Max length allowed for game memos, can be 0.
  function setMaxMemo(uint _maxMemo) external onlyOwner {
    maxMemo = _maxMemo;
  }

  /// @dev Updates the address of the accepted account used to sign submitted moves.
  /// @param _validator Public address of account used to sign moves (if 0 use account that created the contract).
  function setValidator(address _validator) external onlyOwner {
    validator   = (_validator != address(0)) ? _validator : owner;
  }

  /// @dev Updates the address of the account that receives the gameFee.
  /// @param _payee account that receives gameFee, default to owner.
  function setPayee(address payable _payee) external onlyOwner {
    payee   = (_payee != address(0)) ? _payee : owner;
  }

  /// @dev Updates the state of the contract for creating games, making moves.
  /// @param _open If true, allow new games to be created.
  /// @param _playing If true, allow moves to be submitted to existing games.
  function setStatus(bool _open, bool _playing) external onlyOwner {
    open    = _open;
    playing = _playing;
  }

  /// Private methods that modify game state


  /// @dev All transfers are implemented in this internal method.
  /// @param _game The game to update.
  function _makePayments(Game storage _game) internal {
    if (_game.gameOverState == GameOverState.GameNotOver) {
      return;
    }

    if (_game.fundsPaid) {
      return;
    }
    // Make sure this is set before anyone gets paid to prevent
    // possible re-entry attack.
    _game.fundsPaid = true;
   
    // Check Mate
    if (_game.gameOverState ==  GameOverState.CheckMate) {
      _game.winner.transfer((_game.amount * 2) - _game.gameFee);
      payee.transfer(_game.gameFee);
      return;
    }
   
    // Stale Mate
    if (_game.gameOverState == GameOverState.StaleMate) {
      _game.black.transfer(_game.amount);
      _game.white.transfer(_game.amount);
      return;
    }

    // Draw
    if (_game.gameOverState == GameOverState.Draw) {
      _game.black.transfer(_game.amount);
      _game.white.transfer(_game.amount);
      return;
    }

    // Contract Not Playing
    // If the contract is not in a playing state, something went
    // wrong and we want folks to be able to get their money back
    if (!playing) {
      _game.black.transfer(_game.amount);
      if (_game.white != address(0)) {
        _game.white.transfer(_game.amount);
      }
      return;
    }

    // Someone canceled
    if (_game.canceledBy != address(0)) {
      uint amountCanceler = 0;
      uint amountCancelee = 0;
      uint amountPayee = _game.gameFee;
      address payable acctCancelee = (_game.canceledBy == _game.white)
        ? _game.black
        : _game.white;

      // First check if there's only one person in the game.
      // It's an open game anyone could have joined, or a reserved
      // game that has not been joined yet.
      if (_game.white == address(0) || (_game.pendingJoin == true)) {
        // They waited for a day and didn't get a hit
        // so we don't penalize them.
        if ((block.timestamp - _game.createdAt) >= 86400 ) {
          amountCanceler = (_game.amount);
          amountPayee = 0;
        }
        // They were impatient so they get dinged.
        else {
          amountCanceler = (_game.amount - _game.gameFee);
        }
      }
      else
      // If it was canceled by the current turn player
      // they are forfeiting for sure (since they could play)
      // the waiting player gets all the spoils
      if (_game.turn == _game.canceledBy) {
          amountCanceler = 0;
          amountCancelee = ((_game.amount * 2) - _game.gameFee);
      }
       // Game is being canceled by the opponent of current turn player
      else {
        // Current turn player has let the clock run out
        // We will interpret that as a forfeit
        // The waiting player gets the spoils
        if ((block.timestamp - _game.updatedAt) > (_game.turnTimeout)) {
          amountCanceler = ((_game.amount * 2) - _game.gameFee);
        }
        /// Not a timeout, so the player waiting for a turn is forfeiting
        // The current turn player gets the spoils
        else { 
          amountCancelee = ((_game.amount * 2) - _game.gameFee);
        }
      }
      if (amountCanceler > 0) {
        _game.canceledBy.transfer(amountCanceler);
      }
      if (amountCancelee > 0) {
        acctCancelee.transfer(amountCancelee);
      }
      payee.transfer(amountPayee);
    }
  }

  ///  Methods that update state

  /// @notice Sender creates a game.
  /// @dev If address _white is valid, will reserve for that account. Emits GameCreated.
  /// @param _clientId Hash of a user generated id for the game, for lookups - invites
  /// @param _white Address of the "reserved" opponent.  Set to address(0) to allow anyone.
  /// @param _turnTimeout If set to a number > 0, will make the game elligible for forfeit if _turnTimeout expires without player taking their turn. If set to 0 will default to contract 1 day. Otherwise must be between minExpire and maxExpire.
  function createGame(bytes32 _clientId, address _white, uint _turnTimeout)
    external payable ifOpen {
    require(msg.value >= minStake, 'Insufficient funds');
    require(
      (_turnTimeout < 1) ||
      ((_turnTimeout >= minExpire) && (_turnTimeout <=  maxExpire)),
      'Invalid turnTimeout'
    );
    uint fee = ((gameFeePct > 0) && (msg.value > 0)) ? 
        ((msg.value * 1 * 100 * gameFeePct) / 10000)  : 0;

    Game memory g = Game({
      clientId:         _clientId,         
      amount:           msg.value,         
      gameFee:          (_white == address(0)) ? fee : fee / 2,
      board:            DEFAULT_BOARD,
      lastMoveFrom:     '',
      lastMoveTo:       '',
      memo:             '',
      gameOverState:    GameOverState.GameNotOver,                 
      black:            payable(msg.sender),
      white:            payable(_white),
      winner:           payable(address(0)),
      canceledBy:       payable(address(0)),
      turn:             address(0),
      memoUpdatedBy:    address(0),
      pendingJoin:      _white != address(0),             
      fundsPaid:        false,             
      turnTimeout:      (_turnTimeout < 1 ? 86400 : _turnTimeout),
      createdAt:        block.timestamp,
      updatedAt:        block.timestamp,
      memoUpdatedAt:    0
    });
    games.push(g);
    uint gameId = games.length - 1;
    emit GameCreated(gameId, _clientId, msg.sender, _white, msg.value);
  }

  /// @notice Sender cancels game.  May incur penalties depending on timing, turn.
  /// @dev See _makePayments for logic used to determine whether there are penalties. Emits GameCanceled.
  /// @param _id The contracts identifier for the game to be canceled.
  function cancelGame(uint _id) external {
    Game storage g = games[_id];
    require(g.gameOverState == GameOverState.GameNotOver, 'Game over');
    require(g.fundsPaid == false, 'Game over');
    require(msg.sender != address(0), 'Unauthorized');
    require(msg.sender == g.black || msg.sender == g.white, 'Unauthorized');
    g.gameOverState = GameOverState.Canceled;
    g.canceledBy = payable(msg.sender);
    _makePayments(g);
    g.updatedAt = block.timestamp;
    emit GameCanceled(_id, g.canceledBy);
  }

  /// @notice Joins sender to an open game.
  /// @dev Performs checks on whether game is rerved for other sender, if its open, etc. Emits GameJoined.
  /// @param _id The contracts identifier for the game to be joined.
  function joinGame(uint _id) external payable ifOpen {
    Game storage g = games[_id];
    require(g.gameOverState == GameOverState.GameNotOver, 'Game over');
    require((g.pendingJoin == false && g.white == address(0)) || 
            (g.pendingJoin == true && g.white == msg.sender), 'Forbidden');
    require(g.black != msg.sender, 'Forbidden');
    require(g.amount >= msg.value, 'Too much funds');
    require(g.amount <= msg.value, 'Insufficient funds');
    g.white = payable(msg.sender);
    g.turn = g.white;
    g.pendingJoin = false;
    g.updatedAt = block.timestamp;
    emit GameJoined(_id, g.clientId, msg.sender);
  }

  function setGameMemo(uint _id, string calldata _memo) external  {
    Game storage g = games[_id];
    require(msg.sender == g.black || msg.sender == g.white, 'Unauthorized');
    require(g.gameOverState == GameOverState.GameNotOver, 'Game over');
    bytes memory tmp = bytes(_memo);
    require(tmp.length <= maxMemo, 'Memo exceeds max');
    g.memo = _memo;
    g.memoUpdatedBy = msg.sender;
    g.memoUpdatedAt = block.timestamp;
    emit GameMemoUpdated(_id, msg.sender, block.timestamp, _memo);
  }

  /// @notice Evaluates and records a player move.  If the move ends the game, that is
  /// implemented here.
  /// @dev Accepts a move that has been signed by the external validation service. Emits TurnTaken, possibly CheckMate or StaleMate
  /// @param _id The contracts identifier for the game.
  /// @param _moveFrom The algebraic notation of the origin square of the move.
  /// @param _moveTo The algebraic notation of the move being made.
  /// @param _newBoard The board as it is rendered (FEN) after the move is applied
  /// @param _gameOverState Should be 0 (not over) or CheckMate, StaleMate or Draw.
  /// @param _message A hash of the current board + move + newBoard + gameOverState.
  /// @param _signature The signature used to sign the message hash. The signature account must match the contract's validator account.
  function makeMove(uint _id, string calldata _moveFrom, string calldata _moveTo, string calldata _newBoard,
    GameOverState _gameOverState, bytes32 _message, bytes calldata _signature) external ifPlaying {
    require(ECDSA.recover(_message, _signature) == validator, 'Bad signature');
    Game storage g = games[_id];
    require(msg.sender == g.black || msg.sender == g.white, 'Unauthorized');
    require(g.gameOverState == GameOverState.GameNotOver, 'Game over');
    if (g.turn == g.white) {
        require(g.white == msg.sender, 'Forbidden');
    } else {
        require(g.black == msg.sender, 'Forbidden');
    }
    require(keccak256(abi.encodePacked(g.board,_moveFrom,_moveTo,_newBoard,_gameOverState)) == _message,
      'Bad request');
    string memory oldBoard = g.board;

    g.board = _newBoard;
    g.lastMoveFrom = _moveFrom;
    g.lastMoveTo = _moveTo;
    g.gameOverState = _gameOverState;
    g.turn  = (g.turn == g.white) ? g.black : g.white; 
    g.updatedAt = block.timestamp;

    emit TurnTaken(_id, g.clientId, msg.sender, oldBoard, _moveTo, uint8(_gameOverState));

    if (_gameOverState == GameOverState.CheckMate) {
        g.winner = payable(msg.sender);
        emit CheckMate(_id, g.clientId, msg.sender);
        _makePayments(g);
    } else 
    if (_gameOverState == GameOverState.StaleMate) {
        emit StaleMate(_id, g.clientId);
        _makePayments(g);
    } else
    if (_gameOverState == GameOverState.Draw) {
        emit Draw(_id, g.clientId);
        _makePayments(g);
    }
  }

  /// @notice Enables fans to send tips.
  /// @dev Funds are auto transferred to contract payee account. Emits TipReceived
  /// @param _msg A message to put in the event log.
  function tip(string calldata _msg) external payable {
    require(payee != msg.sender, 'Forbidden');
    require(msg.value > 0, 'Thanks for nothin');
    payee.transfer(msg.value);
    emit TipReceived(msg.sender, msg.value, _msg);
  }

  /// @notice Receive function to ensure only owner or payee can send funds. Trying to derisk random folks locking funds in the contract.
  receive() external payable {
    require(msg.sender == payee || msg.sender == owner, 'Forbidden');
    require(msg.value > 0, 'Thanks for nothin');
  }

  //  Methods that read state

  /// @notice Returns the number of games that have been created.
  /// @return uint, number of games created.
  function getGamesCount() public view returns (uint) {
    return games.length; 
  }

  /// @notice Returns list of created games.
  /// @dev Works with pagination, not sure if this is necessary, but could be helpful.
  /// @param _limit Number of games to return.
  /// @param _offset Zero based offset for current page of data.
  /// @return array of Game structs.
  function getGames(uint _limit, uint _offset) public view returns (Game[] memory) {
    Game[] memory tmp = new Game[](
      (_offset + _limit) > games.length 
        ? games.length - _offset
        : _limit
    );
    if (games.length == 0) {
      return tmp;
    }
    uint idx = 0;
    uint eof = ((_offset + _limit) > games.length) 
      ? games.length
      : (_offset + _limit);
    for (uint i = _offset; i < eof; i++) {
      Game storage _g = games[i];
      tmp[idx++] = _g;
    }
    return tmp;
  }

  /// @notice Returns a single game based on gameId.
  /// @dev gameId is the array index of the game in the games array.
  /// @param id Index of the requrested game.
  /// @return Game struct.
  function getGameById(uint id) public view returns (Game memory) {
    return games[id];
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}