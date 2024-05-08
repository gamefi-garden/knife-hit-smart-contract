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
        

        gameConfig = KnifeHitLogic.KnifeHitGameConfig({
        gameDuration: 30000,
        ratio: 50,
        configs: [
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 9,
            obstacle: 1073743104 //800- 1000 - 3000
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
        }),  
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 4,
            obstacle: 1073782784
        })]
        });

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

    function getMatches(uint64[] calldata matchIds) external view returns (
        KnifeHitMatchData[] memory
    ) {
        uint256 matchNumber = matchIds.length;
        KnifeHitMatchData[] memory rspMatches = new KnifeHitMatchData[](matchNumber);
        for (uint256 i = 0; i < matchNumber; ++i) {
            rspMatches[i] = matches[matchIds[i]];
        }
        return rspMatches;
    }

   function getGameConfig() external view returns (
        KnifeHitLogic.KnifeHitGameConfig memory
    ) {
        console.log("getGameConfig");
        console.log(gameConfig.configs.length);

        return gameConfig;
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
            console.log("Room Id");
            console.log(availableMatches.values[i]);
            console.log(matchData.gamePhase == GamePhase.Playing);
            console.log(matchData.playerAddresses[0]);
            console.log(matchData.playerAddresses[0] != msg.sender);

            if (matchData.gamePhase == GamePhase.Playing
            && matchData.playerAddresses[0] != msg.sender) {

                matchId = matchData.matchId;
                roomFound = true;
                break;
            }
        }
        console.log("[FindMatch] => roomFound: ");
        console.log(roomFound);

        if (!roomFound)
        {
            console.log("[Create Match]");

            matchId = ++matchNumber;
            console.log("matchId:");
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
            Set.insert(availableMatches,matchId);

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
                winner = address(this);
                emit KnifeHitMatchFulfillment(matchId, msg.sender, ADDRESS_ZERO);
            }
            matchDataJoin.gamePhase = GamePhase.End;
// erase();
            // matchId
            // availableMatches.erase(matchId);
            Set. erase(availableMatches,matchId);

        }
    }
}
