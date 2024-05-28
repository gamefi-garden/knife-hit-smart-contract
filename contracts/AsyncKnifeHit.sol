// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {IAsyncKnifeHit} from "./interfaces/IAsyncKnifeHit.sol";
import {KnifeHitLogic} from "./libraries/KnifeHitLogic.sol";
import {Set} from "contracts/libraries/Set.sol";
import {IAsyncGameHub} from "./submodule/acrade-async-base-contract/contracts/IAsyncGameHub.sol";
import {BaseAsyncMatchingGame} from "contracts/submodule/acrade-async-base-contract/contracts/BaseAsyncMatchingGame.sol";

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
BaseAsyncMatchingGame,
ReentrancyGuardUpgradeable {
    address constant private ADDRESS_ZERO = address(0);
    uint8 constant private LOGIC_VERSION = 1;

    function onInitialized() override internal{

        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();

        gameConfig = KnifeHitLogic.KnifeHitGameConfig({
        gameDuration: 30000,
        ratio: 30,
        configs: [
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 4,
            obstacle: 257 //0-1600

        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 5,
            obstacle: 32769 //0-3000
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 5,
            obstacle:  262401 //0-1600-3600
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 5,
            obstacle:  268697856 //5600-1600-3600
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 6,
            obstacle:  270344 //600-2600-3600
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 6000,
            knifeCount: 6,
            obstacle:  67371584 //1200-1800-3600-5200
        }),
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 6,
            obstacle:  294977 //1200-3000-0-3600
        }),   
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 9,
            obstacle:  17047618 //200-1200-2600-3600-4800
        }), 
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 9,
            obstacle:  151027780 //400-1200-3000-4800-5400
        }),  
        KnifeHitLogic.KnifeHitLevelConfig({
            easeType: 0,
            rotateSpeed: 5000,
            knifeCount: 10,
            obstacle:  272908562 //200-800-1600-2800-3600-4400-5600
        })]
        });

        emit Initialize();

    }

    function version() external pure override(BaseAsyncMatchingGame, IAsyncKnifeHit) returns (string memory) {
        return "v0.0.1";
    }


   function getGameConfig() external view returns (
        KnifeHitLogic.KnifeHitGameConfig memory
    ) {

        return gameConfig;
    }


    function findMatchV2(
        address _token,
        uint256 _entry,
        uint32[] memory _actions
    ) external payable nonReentrant whenNotPaused {


        console.log("findMatchV2");
        if (_token == ADDRESS_ZERO) {
            if (_entry > msg.value) revert InsufficientFunds();
        } else {
            IERC20Upgradeable(_token).transferFrom(msg.sender, address(this), _entry);
        }

        console.log("findMatch");


        uint64 matchId = IAsyncGameHub(asyncGameHubAddress).findMatch{value: msg.value}(
            msg.sender,
            _token,
            _entry,
            2
        );


        console.log(matchId);

        KnifeHitMatchData storage matchData = matches[matchId];


        address[] memory playerAddresses = IAsyncGameHub(asyncGameHubAddress).getMatchPlayerAddresses(matchId);

        if (msg.sender == playerAddresses[0]) 
        {
            matchData.playerAddresses[0] = msg.sender;
            matchData.player1Actions = _actions;

            matchData.logicVersion = LOGIC_VERSION;
            uint32 score = KnifeHitLogic.CalculateScore(_actions,gameConfig);

            IAsyncGameHub(asyncGameHubAddress).setScore( matchId,
                msg.sender,
                score);
        }
        else
        {
            matchData.playerAddresses[1] = msg.sender;
            matchData.player2Actions = _actions;

            uint32 score = KnifeHitLogic.CalculateScore(_actions,gameConfig);

            uint32 result = KnifeHitLogic.compare(
            matchData.player1Actions,
            matchData.player2Actions,
            gameConfig
            );

            console.log("result");
            console.log(result);
            address winner;

            if (result > 0) {
                winner = matchData.playerAddresses[0];
            emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
            } else if (result < 0) {
                winner = matchData.playerAddresses[1];
                emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
            } else {
                winner = address(this);
                emit KnifeHitMatchFulfillment(matchId, msg.sender, ADDRESS_ZERO);

            IAsyncGameHub(asyncGameHubAddress).setScore(
            matchId,
            msg.sender,
            score
            );
        }
    }
    }

  
}
