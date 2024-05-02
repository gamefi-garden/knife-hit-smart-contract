// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {KnifeHitLogic} from "../libraries/KnifeHitLogic.sol";

import {IAsyncGameHub} from "./IAsyncGameHub.sol";

interface IAsyncKnifeHit {
    struct KnifeHitMatchData {
        uint8 logicVersion;
        uint32[][10] player1Actions;
        uint32[][10] player2Actions;
        KnifeHitLogic.KnifeHitGameConfig config;
    }

    event GameHubUpdate(address newAddress);

    event KnifeHitMatchAbortion(uint64 matchId);
    event KnifeHitMatchCreation(uint64 matchId, address creator);
    event KnifeHitMatchFulfillment(uint64 matchId, address player, address winner);

    error InvalidActionNumber();
    error InvalidMatchAborting();
    error Unauthorized();

    function version() external pure returns (string memory version);

    function gameHub() external view returns (address gameHub);

    function getMatch(uint64 matchId) external view returns (
        KnifeHitMatchData memory KnifeHitMatchData,
        IAsyncGameHub.BriefMatchData memory gameHubMatchData
    );
    function getMatches(uint64[] calldata matchIds) external view returns (
        KnifeHitMatchData[] memory knifeHitMatches,
        IAsyncGameHub.BriefMatchData[] memory gameHubMatches
    );

    function abortMatch(uint64 matchId) external;

    function findMatch(
        address _token,
        uint256 _entry,
        uint32[][10] memory _actions
    ) external payable ;
}
