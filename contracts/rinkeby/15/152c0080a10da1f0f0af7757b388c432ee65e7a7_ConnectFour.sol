/**
 *Submitted for verification at Etherscan.io on 2022-09-09
*/

//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

/// @title ConnectFour
/// @author Bloomtech
/// @custom:revision 2.0: @zasnicoff, July 2022
/// changed pragma to 0.8.9, added BoardUpdated event to be used in future Sprints
/// @notice Allows any two players to place a 50-50 bet on who will win a game of Connect Four.
/// @notice For info on the rules of Connect Four, see https://en.wikipedia.org/wiki/Connect_Four
/// @dev See the {Game} struct for details on how the board is represented
/// @dev Some variables use the uint8 or uint16 type to make it easier for frontend apps to manipulate return values and events, avoiding BigNumbers type conversions. But this might limit the number of concurrent games or cause overflows.



contract ConnectFour {
    /// @dev represents a single disc in the Connect Four board
    enum Disc {
        Empty,
        Player1,
        Player2
    }

    /// @dev status of an individual Game
    enum Status {
        NonExistent,
        Initialized,
        Started,
        BetWithdrawn
    }

    /// @dev indicates the direction to check the winning line of 4 discs
    enum WinningDirection {
        LeftDiagonal,
        Up,
        RightDiagonal,
        Right
    }

    /// @notice struct to represent a Connect Four game between 2 opponents. Each opponent
    /// enters the game by sending the betAmount, so that each game will have a pool of 2 * betAmount
    /// @dev player1 is the address who called ConnectFour.initializeGame, and player2
    /// is the player that called ConnectFour.startGame
    /// @dev each board is comprised of 7 columns, 6 rows, and starts out with each Cell initialized
    /// to Cell.Empty. The board is a single array, and to get the correct disc given a column and row
    /// ID (which are 0-indexed), see ConnectFour.boardIndex. We represent a position in the board as a tuple of
    /// (column, row). The disc (0, 0) is in the bottom left of the board and the disc in the top left of
    /// the board has the coordinates (0, 5) and exists at index 35 in the board array
    ///
    /// See this ASCII grid below for the board and the indexes of different slots
    ///
    /// -------------------------
    /// |/35/  /  /  /  /  /41/|
    /// |/  /  /  /  /  /  /  /|
    /// |/  /  /  /  /  /  /  /|
    /// |/  /  /  /  /  /  /  /|
    /// |/  /  /  /  /  /  /  /|
    /// |/0 /  /  /  /  /  /6 /|
    /// -------------------------

    struct Game {
        address player1; // address of the player that first initialized the game and chose the betAmount
        address player2; // address of the player that started the previously initialized game
        Disc[42] board; // array representing the state of board's discs in a 7 column 6 row grid, at first all are empty
        uint256 betAmount; // number of wei each player bets on the game; the winner will receive 2 * betAmount
        Status status; // various states that denote the lifecycle of a game
        bool isPlayer1Turn; // true if it is player 1's turn, false if it is player 2's turn. Initially it is player 1's turn
    }

    event GameInitialized(uint256 gameId, address player1, uint256 betAmount);

    event GameStarted(uint256 gameId, address player2);

    event RewardClaimed(
        uint256 gameId,
        address winner,
        address recipient,
        uint256 rewardAmount
    );

    /// @dev only the last move idx is sent; frontend logic should keep a record of all the moves or query the blockchain (event filters) to update the local copy of the board. Maybe implement a getter method to return the full board.
    event BoardUpdated(uint256 gameId, Disc player, uint256 boardIdx);

    /// @notice stores the Game structs for each game, identified by each uint256 game ID
    mapping(uint256 => Game) public games;

    /// @notice the minimum amount of wei that can be bet in a game. Setting a higher value (e.g. 1 ETH) indicates
    /// this is a contract meant for whales only. Set this lower if you want everyone to participate
    uint256 public minBetAmount;

    /// @notice the maximum amount of wei that can be bet in a game. Set this to ensure people don't lose their shirts :D
    uint256 public maxBetAmount;

    /// @dev A monotonically incrementing counter used for new Game IDs. Starts out at 0, and increments by 1 with every new Game
    uint256 internal gameIdCounter = 0;

    /// @notice Set the minimum and maximum amounts that can be bet on any Games created through
    /// this contract
    /// @dev Increase _minBetAmount if you want to attract degenerates, lower _maxBetAmount to keep them away
    /// @param _minBetAmount the lowest amount a player will be able to bet
    /// @param _maxBetAmount the largest amount a player will be able to bet
    constructor(uint256 _minBetAmount, uint256 _maxBetAmount) {
        minBetAmount = _minBetAmount;
        maxBetAmount = _maxBetAmount;
    }

    /// @notice Create a Game that can be started by any other address. To start a game the caller
    /// must send an ETH amount between the min and max bet amounts
    /// @notice Each game is for a 50/50 bet, so when the caller of this functions sends, say, 1 ETH,
    /// the opponent must send in the same amount of ETH in ConnectFour.startGame
    /// @dev the returned gameId is a monotonically increasing ID used to interact with this new Game
    /// @return a game ID, which can be used by each player to interact with the new Game
    function initializeGame() external payable returns (uint256) {
        //require statements
        // console.log("INSIDE INITIALIZE GAME!!");
        // console.log('msg.value: ', msg.value);
        // console.log('minBetAmount: ', minBetAmount);
        // console.log('maxBetAmount: ', maxBetAmount);

        require(msg.value >= minBetAmount && msg.value <= maxBetAmount, "ConnectFour: Value must be above min and below max");


        uint256 gameId = gameIdCounter;
        Disc[42] memory board;
        games[gameId] = Game(
            msg.sender,
            address(0),
            board,
            msg.value,
            Status.Initialized,
            true
        );
        // then perform any logic
        gameIdCounter++;
        // finally emit events and return whatever we need to return
        emit GameInitialized(gameId, msg.sender, msg.value);

        return gameId;
    }

    /// @notice Start a that has already been initialized by player1. The caller of this function (player2)
    /// must send in the same amount of ETH as player1 sent in. Afterwards the Game has started, and players
    /// may call ConnectFour.playMove to place their discs
    /// @param _gameId the game's ID, returned when player1 called ConnectFour.initializeGame
    function startGame(uint256 _gameId) external payable {
        // Requires
        require(games[_gameId].status == Status.Initialized, "ConnectFour: game hasn't started or already exists");
        require(msg.sender != games[_gameId].player1, "ConnectFour: can't start the same game you initialized");
        require(msg.value == games[_gameId].betAmount, "ConnectFour: Bet amount needs to match player 1 bet");


        // Logic
        games[_gameId].status = Status.Started;

        games[_gameId].player2 = msg.sender;

        // Emits
        emit GameStarted(_gameId, msg.sender);
        // console.log("GAME STARTED HERE");
    }

    /// @notice Place a disc in the given column with the given Game. player1 and player2 will take
    /// turns placing one of their discs in a column, where it will fall until it stays in the bottom-most
    /// slot or onto the bottom-most previously-placed disc. For more info on how to play Connect Four, see
    /// the wikipedia page https://en.wikipedia.org/wiki/Connect_Four
    /// @dev illegal moves will cause the transaction to revert, such as placing a disc out of bounds of the 7x6
    /// board, trying to place a disc in a column which is already full, or going out of turn
    /// @param _gameId the game's ID, returned when player1 called ConnectFour.initializeGame
    /// @param _col the index of the column to place a disc in, valid values are 0 through 6 inclusive
    function playMove(uint256 _gameId, uint256 _col) external {
        // Require
        require( _col >= 0 && _col <= 6, "ConnectFour: You must play a disc in a column 1 through 6");
        Game memory game = games[_gameId];
        require(game.status == Status.Started, "ConnectFour: game hasn't started, doesn't exist, or is already over");
        if ( game.isPlayer1Turn ) {
            require( game.player1 == msg.sender, "ConnectFour: it is not your turn");
        } else {
            require( game.player2 == msg.sender , "ConnectFour: it is not your turn");
        }
        
        for (uint256 row = 0; row <= 5; row++){
            uint256 idx = boardIndex(_col, row);
            Disc rowDisc = game.board[idx];

            if ( rowDisc == Disc.Empty ) {
                 games[_gameId].board[idx] = game.isPlayer1Turn ? Disc.Player1 : Disc.Player2;
                 games[_gameId].isPlayer1Turn = !games[_gameId].isPlayer1Turn;
                 break;
            } else if (row == 5) {
                // At this point we have iterated through all rows
                // And this means the column is full and no more peices can be played here
                revert("ConnectFour: column is full");
            }
        }

    }

    /// @notice Withdraws the bet amounts of both players to the recipient for the given game when there exists
    /// a winning four-in-a-row of the caller's discs. The caller specifies the four-in-a-row by providing
    /// starting column and row coordinates, as well as a direction in which to look for the 4 winning discs
    /// @dev As an example, imagine there is a winning four-in-a-row at coordinates (0,0), (0,1), (0,2), (0,3).
    /// Then the following function arguments will correctly claim the reward:
    /// _startingWinDiscCol = 0, _startingWinDiscRow = 0, _direction = Up
    /// @dev Note: there exists a vulnerability in this contract that we will exploit in a later Sprint :D
    /// @param _gameId the game's ID, returned when player1 called ConnectFour.initializeGame
    /// @param _recipient the address who will receive the bet's reward ETH
    /// @param _startingWinDiscCol the column index of one of the two end chips of the four-in-a-row
    /// @param _startingWinDiscRow the row index of one of the two end chips of the four-in-a-row
    /// @param _direction one of 4 possible directions in which to move when verifying the four-in-a-row
    function claimReward(
        uint256 _gameId,
        address payable _recipient,
        uint256 _startingWinDiscCol,
        uint256 _startingWinDiscRow,
        WinningDirection _direction
    ) external {
        // require
        require(games[_gameId].status == Status.Started, "ConnectFour: Cannot claim reward on a game that is not started");
        
        if ( _direction == WinningDirection.Up ) {
            require(_startingWinDiscRow <= 2 && _startingWinDiscRow >= 0, "ConnectFour: This four in a row is out of bounds");
        } else if ( _direction == WinningDirection.Right || _direction == WinningDirection.RightDiagonal ) {
            require(_startingWinDiscCol <= 3 && _startingWinDiscCol >= 0, "ConnectFour: This four in a row is out of bounds");
        } else if ( _direction == WinningDirection.LeftDiagonal) {
            require(_startingWinDiscCol >= 3 && _startingWinDiscCol <= 6, "ConnectFour: This four in a row is out of bounds");
        }

        Game storage game = games[_gameId];

        // logic
        bool hasWon = true;
        if (_direction == WinningDirection.Up ) {
            // uint256 idx = boardIndex(_startingWinDiscCol, _startingWinDiscRow);

            for (uint256 row = _startingWinDiscRow; row <= _startingWinDiscRow + 3; row++){

                uint256 idx = boardIndex(_startingWinDiscCol, row);
                Disc rowDisc = game.board[idx];

                if ( rowDisc != (msg.sender == game.player1 ? Disc.Player1 : Disc.Player2) ) {
                    hasWon = false;
                    break;
                }
                
            }
        } else if (_direction == WinningDirection.Right ) {
            for (uint256 col = _startingWinDiscCol; col <= _startingWinDiscCol + 3; col++){

                uint256 idx = boardIndex(col, _startingWinDiscRow);
                Disc rowDisc = game.board[idx];

                if ( rowDisc != (msg.sender == game.player1 ? Disc.Player1 : Disc.Player2) ) {
                    hasWon = false;
                    break;
                }
                
            }
        } else if (_direction == WinningDirection.RightDiagonal) {

            for (uint256 num = 0; num <= 3; num++){
                uint256 currentCol = _startingWinDiscCol + num;
                uint256 currentRow = _startingWinDiscRow + num;

                uint256 idx = boardIndex(currentCol, currentRow);
                Disc rowDisc = game.board[idx];

                if ( rowDisc != (msg.sender == game.player1 ? Disc.Player1 : Disc.Player2) ) {
                    hasWon = false;
                    break;
                }
                
            }

        } else if (_direction == WinningDirection.LeftDiagonal) {

            for (uint256 num = 0; num <= 3; num++){
                uint256 currentCol = _startingWinDiscCol - num;
                uint256 currentRow = _startingWinDiscRow + num;

                uint256 idx = boardIndex(currentCol, currentRow);
                Disc rowDisc = game.board[idx];

                if ( rowDisc != (msg.sender == game.player1 ? Disc.Player1 : Disc.Player2) ) {
                    hasWon = false;
                    break;
                }
                
            }

        } else {
            revert("ConnectFour: unhandled enum");
        }

        require( hasWon, "ConnectFour: This is not a winning position");

        // if we've made it to this point, then we've know we have a valid set of 4 winning disc, so we should
        // end the game and payout the winner

        uint256 rewardAmount = 2 * games[_gameId].betAmount;
        (bool sent, ) = _recipient.call{value: rewardAmount}("");
        require(sent, "ConnectFour: reward transfer failed");

        /// @notice Game status changes AFTER reward transfer is successful, otherwise game won't be playable is case of transfer failure
        games[_gameId].status = Status.BetWithdrawn;

        // emit
        emit RewardClaimed(
        _gameId,
        msg.sender,
        _recipient,
        rewardAmount
        );

    }

    /// @notice Return the index of a disc in the board, given its column and row index (0-indexed)
    /// @dev this function will throw if the column or row are out of bounds
    /// @param _col the index of the column, valid values are 0 through 6 inclusive
    /// @param _row the index of the row, valid values are 0 through 5 inclusive
    /// @return the index of the board corresponding to these coordinates
    function boardIndex(uint256 _col, uint256 _row)
        public
        pure
        returns (uint256)
    {
        require(_col <= 6 && _row <= 5, "ConnectFour: row or column is out of bounds");

        return (7 * _row) + _col;
    }


}