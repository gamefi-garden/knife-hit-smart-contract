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
    Set.Uint64Set internal playingMatches;
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
        

        gameConfig = KnifeHitLogic.KnifeHitGameConfig({
        knifeMoveTime: 300,
        gameDuration: 30000,
        ratio: 50,
        configs: [
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 9,
            obstacle: 1073743104
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

       KnifeHitMatchData storage matchData = matches[matchNumber];

        console.log("[FindMatch]");
        console.log(matchNumber);
        console.log(matchData.playerAddresses[0] == msg.sender);
        console.log(matchData.gamePhase == GamePhase.End);
        console.log("Check");
        
        console.log(matchData.gamePhase == GamePhase.None);
        console.log(matchData.gamePhase == GamePhase.Playing);
        console.log(matchData.gamePhase == GamePhase.End);
        console.log(matchData.playerAddresses[0] == msg.sender);

        if ( matchData.playerAddresses[0] == msg.sender
            || matchData.gamePhase == GamePhase.End
            || matchData.gamePhase == GamePhase.None )
        {

            console.log("[Create Match]");

            uint64 matchId = ++matchNumber;
            console.log(matchId);

            matchData.matchId = matchId;
            matchData.entry = _entry;
            matchData.token = _token;
            matchData.creator = msg.sender;
            matchData.playerAddresses[0] = msg.sender;
            matchData.logicVersion = LOGIC_VERSION;
            
            matchData.gamePhase = GamePhase.Playing;
            matchData.player1Actions = _actions;

            uint32 score = KnifeHitLogic.CalculateScore(_actions,gameConfig);
            console.log(score);

        }
        else
        {
                console.log("[Join Match]");

                uint64 matchId = matchData.matchId;
                console.log(matchId);

                matchData.playerAddresses[1] = msg.sender;

                matchData.player2Actions = _actions;

                address winner;
                uint32 result = KnifeHitLogic.compare(
                matchData.player1Actions,
                matchData.player2Actions,
                gameConfig
                );

                console.log(result);
                if (result > 0) {
                    winner = matchData.playerAddresses[0];
                emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
                } else if (result < 0) {
                    winner = matchData.playerAddresses[1];
                    emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
                } else {
                    winner = address(this);
                    emit KnifeHitMatchFulfillment(matchId, msg.sender, ADDRESS_ZERO);
                }
                matchData.gamePhase = GamePhase.End;
        }
    }
}
