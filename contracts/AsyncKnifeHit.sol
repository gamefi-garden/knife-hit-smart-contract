// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// import {IAsyncGameHub} from "./interfaces/IAsyncGameHub.sol";
import {IAsyncKnifeHit} from "./interfaces/IAsyncKnifeHit.sol";
import {KnifeHitLogic} from "./libraries/KnifeHitLogic.sol";
import {Set} from "contracts/libraries/Set.sol";
import "hardhat/console.sol";



abstract contract AsyncKnifeHitStorage is IAsyncKnifeHit {
    mapping(uint64 => KnifeHitMatchData) internal matches;

    Set.Uint64Set internal availableMatches;

    mapping(address => Set.Uint64Set) internal playerPlayingMatches;
    mapping(address => Set.Uint64Set) internal playerEndedMatches;

    KnifeHitLogic.KnifeHitGameConfig public gameConfig;
    uint64 public matchNumber;

}
contract AsyncKnifeHit is
AsyncKnifeHitStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    address constant private ADDRESS_ZERO = address(0);
    uint8 constant private LOGIC_VERSION = 1;

    function initialize(address _treasury) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        
        console.log("initialize");

        console.log(_treasury);

        gameConfig = KnifeHitLogic.KnifeHitGameConfig({
        gameDuration: 30000,
        ratio: 30,
        configs: [
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 9,
            obstacle: 32816 //800- 1000 - 3000
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 4,
            obstacle: 32816
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 4,
            obstacle: 1073782784
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 4,
            obstacle: 1073782784
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 4,
            obstacle: 1073782784
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 4,
            obstacle: 1073782784
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 4,
            obstacle: 1073782784
        }),   
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 4,
            obstacle: 1073782784
        }), 
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 4,
            obstacle: 1073782784
        }),  
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 4,
            obstacle: 1073782784
        })]
        });

        
        Set.insert(playerPlayingMatches[0xCa507f10C53a5F5bAE8577f0309755d5179965aF],1);
        KnifeHitMatchData storage matchData1 = matches[1];
        matchData1.playerScore[0] = 10;
        matchData1.gamePhase == GamePhase.Playing;

        Set.insert(playerPlayingMatches[0xCa507f10C53a5F5bAE8577f0309755d5179965aF],2);
        KnifeHitMatchData storage matchData2 = matches[2];
        matchData2.playerScore[0] = 10;
        matchData2.gamePhase == GamePhase.Playing;

        Set.insert(playerPlayingMatches[0xCa507f10C53a5F5bAE8577f0309755d5179965aF],3);
        KnifeHitMatchData storage matchData3 = matches[3];
        matchData3.playerScore[0] = 10;
        matchData3.gamePhase == GamePhase.Playing;
      

        Set.insert(playerEndedMatches[0xCa507f10C53a5F5bAE8577f0309755d5179965aF],4);
        KnifeHitMatchData storage matchData4 = matches[4];
        matchData4.playerScore[0] = 10;
        matchData4.playerScore[1] = 10;
        matchData4.gamePhase == GamePhase.End;

        Set.insert(playerEndedMatches[0xCa507f10C53a5F5bAE8577f0309755d5179965aF],5);
     
        KnifeHitMatchData storage matchData5 = matches[5];
        matchData5.playerScore[0] = 5;
        matchData5.playerScore[1] = 10;

        Set.insert(playerEndedMatches[0xCa507f10C53a5F5bAE8577f0309755d5179965aF],6);
        KnifeHitMatchData storage matchData6 = matches[6];

        matchData6.playerScore[0] = 10;
        matchData6.playerScore[1] = 5;

        emit Initialize();

    }

    function version() external pure returns (string memory) {
        return "v0.0.1";
    }


    function getMatch(uint64 _matchId) external view returns (
        KnifeHitMatchData memory
    ) {
        KnifeHitMatchData memory matchData = matches[_matchId];
        return matchData;
    }


    function getMatches(uint64[] memory matchIds) public view returns (KnifeHitMatchData[] memory) {
        uint256 matchNumber = matchIds.length;
        KnifeHitMatchData[] memory rspMatches = new KnifeHitMatchData[](matchNumber);
        for (uint256 i = 0; i < matchNumber; ++i) {
            rspMatches[i] = matches[matchIds[i]];
        }
        console.log("getMatches");

        console.log(matchIds.length);

        return rspMatches;
    }

   function getGameConfig() external view returns (
        KnifeHitLogic.KnifeHitGameConfig memory
    ) {

        return gameConfig;
    }

   function getPlayingMatchDataOf(address _player) external view returns (KnifeHitMatchData[] memory) {
        uint64[] memory matchIds = getPlayingMatchesOf(_player);
        console.log("getPlayingMatchDataOf");
        console.log(matchIds.length);
        return getMatches(matchIds);
    }

    function getEndMatchDataOf(address _player) external view returns (KnifeHitMatchData[] memory) {
        uint64[] memory matchIds = getEndMatchesOf(_player);
        console.log("getPlayinggetEndMatchDataOfMatchDataOf");
        console.log(matchIds.length);
        return getMatches(matchIds);
    }

    function getEndMatchesOf(address _player) public view returns (uint64[] memory) {
        return playerEndedMatches[_player].values;
    }

    function getPlayingMatchesOf(address _player) public view returns (uint64[] memory) {
        return playerPlayingMatches[_player].values;
    }


    function findMatch(
        address _token,
        uint256 _entry,
        uint32[] memory _actions
    ) external payable nonReentrant whenNotPaused {

        bool roomFound = false;
        KnifeHitMatchData memory matchData;
        uint64 matchId = 0;
        console.log("[Find Room]");


        for (uint i = 0; i < availableMatches.values.length; i++) {

                // matches
            matchData = matches[availableMatches.values[i]];
            // console.log("Room Id");
            // console.log(availableMatches.values[i]);
            // console.log(matchData.gamePhase == GamePhase.Playing);
            // console.log(matchData.playerAddresses[0]);
            // console.log(matchData.playerAddresses[0] != msg.sender);

            if (matchData.gamePhase == GamePhase.Playing
            && matchData.playerAddresses[0] != msg.sender) {

                matchId = matchData.matchId;
                roomFound = true;
                break;
            }
        }
        // console.log("[FindMatch] => roomFound: ");
        // console.log(roomFound);

        if (!roomFound)
        {

            matchId = ++matchNumber;
            // console.log("matchId:");
            console.log(matchId);
            KnifeHitMatchData storage matchDataCreate = matches[matchId];
            matchDataCreate.matchId = matchId;
            matchDataCreate.entry = _entry;
            matchDataCreate.token = _token;
            matchDataCreate.creator = msg.sender;
            matchDataCreate.playerAddresses[0] = msg.sender;
            matchDataCreate.logicVersion = LOGIC_VERSION;
            matchDataCreate.gamePhase = GamePhase.Playing;
            matchDataCreate.player1Actions = _actions;

            uint32 score = KnifeHitLogic.CalculateScore(_actions,gameConfig);
            console.log(score);
            // availableMatches.insert(matchId);

            console.log("[Create Match]");
            console.log("matchId");
            console.log(matchId);

            console.log(Set.size(availableMatches));

            Set.insert(availableMatches,matchId);
                        console.log(Set.size(availableMatches));

            console.log("=======");
            console.log(Set.size(playerPlayingMatches[msg.sender]));

            Set.insert(playerPlayingMatches[msg.sender],matchId);
            // playerPlayingMatches[msg.sender].insert(matchId);
            // playerPlayingMatches[msg.sender].insert(matchId);
        

        }
        else
        {
            console.log("[Join Match]");
            console.log("matchId:");
            console.log(matchId);
            KnifeHitMatchData storage matchDataJoin = matches[matchId];

            matchDataJoin.playerAddresses[1] = msg.sender;

            matchDataJoin.player2Actions = _actions;

            address winner;
            uint32 result = KnifeHitLogic.compare(
            matchDataJoin.player1Actions,
            matchDataJoin.player2Actions,
            gameConfig
            );
            console.log("result");
            console.log(result);
            if (result > 0) {
                winner = matchDataJoin.playerAddresses[0];
            emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
            } else if (result < 0) {
                winner = matchDataJoin.playerAddresses[1];
                emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
            } else {
                // winner = address(this);
                winner = ADDRESS_ZERO;
                emit KnifeHitMatchFulfillment(matchId, msg.sender, ADDRESS_ZERO);
            }
            matchDataJoin.gamePhase = GamePhase.End;
            matchDataJoin.winer = winner;

            Set.erase(availableMatches,matchId);

            address player0 = matchDataJoin.playerAddresses[0];

            Set.erase(playerPlayingMatches[player0],matchId);
            Set.insert(playerEndedMatches[player0],matchId);

            Set.insert(playerEndedMatches[msg.sender],matchId);

            uint256 entry = matchDataJoin.entry;
            address token = matchDataJoin.token;

            uint256 totalValue = entry * matchDataJoin.playerAddresses.length;

            console.log("End");
            console.log(matchDataJoin.winer);

            if (matchDataJoin.winer != ADDRESS_ZERO)
            {
                uint256 fee = totalValue * feePercentage / 100;
                uint256 prize = totalValue - fee;

                console.log(fee);
                console.log(prize);
                console.log(token);

                 if (token == ADDRESS_ZERO) {
                     if (fee != 0) {
                        (bool success, ) = treasury.call{value: fee}("");
                            console.log(success);

                            if (!success) revert FailedTransfer();
                        }
                        if (prize != 0) {
                            (bool success, ) = matchDataJoin.winer.call{value: prize}("");

                            console.log(success);
                            if (!success) revert FailedTransfer();
                        }
                 }
                 else{
                    console.log("else");

                     if (fee != 0) {
                            // IERC20Upgradeable(token).transferFrom(msg.sender,treasury, fee);
                            IERC20Upgradeable(token).transfer(treasury, fee);

                        }
                        if (prize != 0) {
                            // IERC20Upgradeable(token).transferFrom(msg.sender,matchDataJoin.winer, prize);
                            IERC20Upgradeable(token).transfer(matchDataJoin.winer, prize);
                        }
                 }


            }
            else
            {
                // transfer
                    if (token == ADDRESS_ZERO) {
                        (bool success,) = treasury.call{value: totalValue}("");
                        if (!success) revert FailedTransfer();
                    } else {
                        // IERC20Upgradeable(token).transferFrom(msg.sender,treasury, totalValue);
                        IERC20Upgradeable(token).transfer(treasury, totalValue);

                    }
            }
        }

        emit KnifeFindMatch(matchId);

    }
}
