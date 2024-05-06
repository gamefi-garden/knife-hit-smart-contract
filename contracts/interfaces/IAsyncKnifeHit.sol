// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {KnifeHitLogic} from "../libraries/KnifeHitLogic.sol";

   

interface IAsyncKnifeHit {
     enum GamePhase {
        None,
        Playing,
        End
    }
    struct KnifeHitMatchData {
        uint64 matchId ;
        address token;
        uint256 entry;
        address creator;
        uint8 logicVersion;
        GamePhase gamePhase;
        address[] playerAddresses;
        uint32[10][] player1Actions;
        uint32[10][] player2Actions;
        KnifeHitLogic.KnifeHitGameConfig config;
    }


    event KnifeHitMatchAbortion(uint64 matchId);
    event KnifeHitMatchCreation(uint64 matchId, address creator);
    event KnifeHitMatchFulfillment(uint64 matchId, address player, address winner);

    error InvalidActionNumber();
    error InvalidMatchAborting();
    error Unauthorized();

    function version() external pure returns (string memory version);


    function getMatch(uint64 matchId) external view returns (
        KnifeHitMatchData memory KnifeHitMatchData);

    function getMatches(uint64[] calldata matchIds) external view returns (
        KnifeHitMatchData[] memory knifeHitMatches);

    function getGameConfig() external view returns (
    KnifeHitLogic.KnifeHitGameConfig memory config);


    function findMatch(
        address _token,
        uint256 _entry,
        uint32[][10] memory _actions
    ) external payable ;
}
