// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

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

    address public treasury;
    uint8 public feePercentage;

    uint64 public matchNumber;

}
contract AsyncKnifeHit is
AsyncKnifeHitStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    address constant private ADDRESS_ZERO = address(0);
    uint8 constant private LOGIC_VERSION = 1;

    function initialize(address _treasury,uint8 _feePercentage) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();

        treasury = _treasury;
        feePercentage = _feePercentage;

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


        if (_token == ADDRESS_ZERO) {
            if (_entry != msg.value) revert InsufficientFunds();
        } else {
            IERC20Upgradeable(_token).transferFrom(msg.sender, address(this), _entry);
        }


        bool roomFound = false;
        KnifeHitMatchData memory matchData;
        uint64 matchId = 0;

        for (uint i = 0; i < availableMatches.values.length; i++) {

            matchData = matches[availableMatches.values[i]];
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
            matchId = ++matchNumber;
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
            matchDataCreate.playerScore[0] = score;

            console.log("[Create Match]");
            console.log(score);

            

            Set.insert(availableMatches,matchId);


            Set.insert(playerPlayingMatches[msg.sender],matchId);
        }
        else
        {
            console.log("[Join Match]");
            console.log("matchId:");
            console.log(matchId);
            KnifeHitMatchData storage matchDataJoin = matches[matchId];

            matchDataJoin.playerAddresses[1] = msg.sender;

            matchDataJoin.player2Actions = _actions;

            uint32 score = KnifeHitLogic.CalculateScore(_actions,gameConfig);
            matchDataJoin.playerScore[1] = score;

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
