// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IAsyncGameHub} from "./interfaces/IAsyncGameHub.sol";
import {IAsyncKnifeHit} from "./interfaces/IAsyncKnifeHit.sol";

import {KnifeHitLogic} from "./libraries/KnifeHitLogic.sol";

abstract contract AsyncKnifeHitStorage is IAsyncKnifeHit {
    mapping(uint64 => KnifeHitMatchData) internal matches;

    address public gameHub;

    uint256[50] private __gap;
}

contract AsyncKnifeHit is
AsyncKnifeHitStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    address constant private ADDRESS_ZERO = address(0);
    uint8 constant private LOGIC_VERSION = 1;
    KnifeHitLogic.KnifeHitGameConfig gameConfig;

    function initialize(address _gameHub) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();

        gameHub = _gameHub;

        emit GameHubUpdate(_gameHub);
    }

    function version() external pure returns (string memory) {
        return "v0.0.1";
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenNotPaused {
        _unpause();
    }

    function updateGameHub(address _gameHub) external onlyOwner {
        gameHub = _gameHub;
        emit GameHubUpdate(_gameHub);
    }

    function getMatch(uint64 _matchId) external view returns (
        KnifeHitMatchData memory,
        IAsyncGameHub.BriefMatchData memory
    ) {
        KnifeHitMatchData memory matchData = matches[_matchId];
        IAsyncGameHub.BriefMatchData memory gameHubMatchData = IAsyncGameHub(gameHub).getMatch(_matchId);

        // if (matchData.playerActions.length != 2 && msg.sender != gameHubMatchData.playerAddresses[0]) {
        //     delete matchData.playerActions;
        // }

        return (matchData, gameHubMatchData);
    }

    function getMatches(uint64[] calldata matchIds) external view returns (
        KnifeHitMatchData[] memory,
        IAsyncGameHub.BriefMatchData[] memory
    ) {
        uint256 matchNumber = matchIds.length;
        KnifeHitMatchData[] memory rspMatches = new KnifeHitMatchData[](matchNumber);
        IAsyncGameHub.BriefMatchData[] memory gameHubMatches = new IAsyncGameHub.BriefMatchData[](matchNumber);
        for (uint256 i = 0; i < matchNumber; ++i) {
            rspMatches[i] = matches[matchIds[i]];
            gameHubMatches[i] = IAsyncGameHub(gameHub).getMatch(matchIds[i]);
        }
        return (rspMatches, gameHubMatches);
    }
    function findMatch(
        address _token,
        uint256 _entry,
        uint32[][10] memory _actions
    ) external payable nonReentrant whenNotPaused {
        uint64 matchId = IAsyncGameHub(gameHub).findMatch{value: msg.value}(
            msg.sender,
            _token,
            _entry,
            2
        );

        KnifeHitMatchData storage matchData = matches[matchId];
        address[] memory playerAddresses = IAsyncGameHub(gameHub).getMatchPlayerAddresses(matchId);

         if (msg.sender == playerAddresses[0]) {
            matchData.player1Actions = _actions;
            matchData.logicVersion = LOGIC_VERSION;
            emit KnifeHitMatchCreation(matchId, msg.sender);

            IAsyncGameHub(gameHub).setScore(
                matchId,
                msg.sender,
                KnifeHitLogic.CalculateScore(_actions,gameConfig),
                ADDRESS_ZERO
            );
        }else {
            matchData.player2Actions = _actions;

             uint32 result = KnifeHitLogic.compare(
                matchData.player1Actions,
                matchData.player2Actions,
                gameConfig
            );


            address winner;
            if (result > 0) {
                winner = playerAddresses[0];
            emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
            } else if (result < 0) {
                winner = playerAddresses[1];
                emit KnifeHitMatchFulfillment(matchId, msg.sender, winner);
            } else {
                winner = address(this);
                emit KnifeHitMatchFulfillment(matchId, msg.sender, ADDRESS_ZERO);
            }

             IAsyncGameHub(gameHub).setScore(
                matchId,
                msg.sender,
                0,
                winner
            );
        }

     
    }

    function abortMatch(uint64 _matchId) external nonReentrant {
        if (IAsyncGameHub(gameHub).getMatchPlayer(_matchId, msg.sender).index == 1) {
            revert InvalidMatchAborting();
        }

        IAsyncGameHub(gameHub).abortMatch(_matchId);

        emit KnifeHitMatchAbortion(_matchId);

    }
}
