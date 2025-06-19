// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";



contract StonePaperScissors {
    using FHE for euint8;
    using FHE for ebool;

    enum GameStatus { WaitingForPlayer, Complete }

    struct Game {
        address player1;
        address player2;
        euint8 move1; // Encrypted move of player1
        euint8 move2; // Encrypted move of player2
        GameStatus status;
    }

    uint public gameIdCounter = 1;
    mapping(uint => Game) public games;

    event GameCreated(uint gameId, address indexed player1);
    event PlayerJoined(uint gameId, address indexed player2);
    event GameResult(uint gameId, string result);

    /// Move: 1 = Stone, 2 = Paper, 3 = Scissor

    function createGame(euint8 encryptedMove) external returns (uint) {
        games[gameIdCounter] = Game({
            player1: msg.sender,
            player2: address(0),
            move1: encryptedMove,
            move2: FHE.asEuint8(0), // placeholder
            status: GameStatus.WaitingForPlayer
        });

        emit GameCreated(gameIdCounter, msg.sender);
        return gameIdCounter++;
    }

    function joinGame(uint gameId, euint8 encryptedMove) external {
        Game storage game = games[gameId];
        require(game.status == GameStatus.WaitingForPlayer, "Game not joinable");
        require(game.player1 != msg.sender, "Cannot join your own game");

        game.player2 = msg.sender;
        game.move2 = encryptedMove;
        game.status = GameStatus.Complete;

        emit PlayerJoined(gameId, msg.sender);

        _revealResult(gameId);
    }

    function _revealResult(uint gameId) internal {
        Game storage game = games[gameId];
        euint8 p1 = game.move1;
        euint8 p2 = game.move2;

        // Tie: if p1 == p2
        ebool isTie = FHE.eq(p1, p2);
        FHE.decrypt(isTie);
        (bool tieResult, bool tieDecrypted) = FHE.getDecryptResultSafe(isTie);
        require(tieDecrypted, "Tie result not ready");
        
        if (tieResult) {
            emit GameResult(gameId, "It's a tie!");
            return;
        }

        // p1 = Stone (1), p2 = Scissor (3)
        ebool stoneBeatsScissor = FHE.and(
            FHE.eq(p1, FHE.asEuint8(1)),
            FHE.eq(p2, FHE.asEuint8(3))
        );

        // p1 = Paper (2), p2 = Stone (1)
        ebool paperBeatsStone = FHE.and(
            FHE.eq(p1, FHE.asEuint8(2)),
            FHE.eq(p2, FHE.asEuint8(1))
        );

        // p1 = Scissor (3), p2 = Paper (2)
        ebool scissorBeatsPaper = FHE.and(
            FHE.eq(p1, FHE.asEuint8(3)),
            FHE.eq(p2, FHE.asEuint8(2))
        );

        // Combine all winning cases
        ebool player1Wins = FHE.or(
            FHE.or(stoneBeatsScissor, paperBeatsStone),
            scissorBeatsPaper
        );

        FHE.decrypt(player1Wins);
        (bool winResult, bool winDecrypted) = FHE.getDecryptResultSafe(player1Wins);
        require(winDecrypted, "Win result not ready");

        if (winResult) {
            emit GameResult(gameId, "Player 1 Wins!");
        } else {
            emit GameResult(gameId, "Player 2 Wins!");
        }
    }
}