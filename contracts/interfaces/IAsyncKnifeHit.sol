// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {KnifeHitLogic} from "../libraries/KnifeHitLogic.sol";
import {IAsyncGameHub} from "../submodule/acrade-async-base-contract/contracts/IAsyncGameHub.sol";

   

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
        address winer;
        uint8 logicVersion;
        GamePhase gamePhase;

        address[2] playerAddresses;

        uint32[] player1Actions;
        uint32[] player2Actions;
        uint32[2] playerScore;

    }
    event KnifeFindMatch(uint64 matchId);

    event Initialize(); 
    event KnifeHitMatchAbortion(uint64 matchId);
    event KnifeHitMatchCreation(uint64 matchId, address creator);
    event KnifeHitMatchFulfillment(uint64 matchId, address player, address winner);

    error InvalidActionNumber();
    error InvalidMatchAborting();
    error Unauthorized();

    error InsufficientFunds();
    error FailedTransfer();

    function version() external pure returns (string memory version);

    function getGameConfig() external view returns (
    KnifeHitLogic.KnifeHitGameConfig memory config);

 
    
    function findMatchV2(
        address _token,
        uint256 _entry,
        uint32[] memory _actions
    ) external payable ;

}
