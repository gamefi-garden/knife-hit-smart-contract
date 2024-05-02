// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IAsyncGameHub {
    enum MatchPhase {
        Nil,
        Playing,
        Ended,
        Aborted
    }

    struct PlayerData {
        uint256 score;
        uint40 deadline;
        uint8 index;
    }

    struct MatchData {
        mapping(address => PlayerData) players;
        address[] playerAddresses;
        uint256 entry;
        address gameAddress;
        uint40 playingTimeLimit;
        uint8 feePercentage;
        uint8 playerNumber;
        MatchPhase phase;
        uint8 playerSubmissions;
        uint8 logicVersion;
        address token;
        address bestPlayer;
    }

    struct BriefMatchData {
        uint64 id;
        address[] playerAddresses;
        uint256 entry;
        address gameAddress;
        uint40 playingTimeLimit;
        uint8 feePercentage;
        uint8 playerNumber;
        MatchPhase phase;
        uint8 playerSubmissions;
        uint8 logicVersion;
        address token;
        address bestPlayer;
    }

    struct BriefPlayerMatchData {
        uint64 id;
        uint256 score;
    }

    event AbortionTimeLimitUpdate(uint40 newValue);
    
    event FeePercentageUpdate(uint8 newValue);
    event GameLibraryUpdate(address newAddress);
    event TreasuryUpdate(address newAddress);

    event MatchAbortion(uint64 matchId);
    event MatchCreation(
        uint64 matchId,
        address creator,
        address gameAddress,
        address token,
        uint256 entry,
        uint8 playerNumber
    );
    event MatchEnd(uint64 matchId);
    event MatchFulfillment(uint64 matchId);
    event MatchJoin(uint64 matchId, address player);

    event ScoreSet(
        uint64 matchId,
        address player,
        uint256 score
    );
    event BestPlayerSet(
        uint64 matchId,
        address player
    );

    error FailedTransfer();
    error GameNotIntegrable();
    error InsufficientFunds();
    error InvalidMatchAborting();
    error InvalidMatchEnding();
    error InvalidMatchId();
    error InvalidParam();
    error InvalidScoreSetting();
    error Unauthorized();

    function version() external pure returns (string memory version);

    function abortionTimeLimit() external view returns (uint40 abortionTimeLimit);
    function feePercentage() external view returns (uint8 feePercentage);
    function gameLibrary() external view returns (address gameLibrary);
    function matchNumber() external view returns (uint64 matchNumber);
    function treasury() external view returns (address treasury);

    function getAbortedMatches() external view returns (uint64[] memory matches);
    function getPlayingMatches() external view returns (uint64[] memory matches);

    function getMatch(uint64 matchId) external view returns (BriefMatchData memory matchData);
    function getMatches(uint64[] calldata matchIds) external view returns (BriefMatchData[] memory matches);
    function getMatchDeadline(uint64 matchId) external view returns (uint40 deadline);
    function getMatchPlayer(uint64 matchId, address player) external view returns (PlayerData memory playerData);
    function getMatchPlayerAddresses(uint64 matchId) external view returns (address[] memory addresses);
    function getMatchPlayers(uint64 matchId) external view returns (
        address[] memory playerAddresses,
        PlayerData[] memory playerData
    );

    function getPlayerHistory(
        address player,
        address gameAddress
    ) external view returns (BriefPlayerMatchData[] memory history);
    function getPlayerPlayingMatches(address player) external view returns (BriefMatchData[] memory matches);
    function getPlayerUnfinishedMatches(address player) external view returns (BriefMatchData[] memory matches);

    function isMatchEnded(uint64 matchId) external view returns (bool ended);
    function isMatchEndable(uint64 matchId) external view returns (bool endable);
    function isMatchPlayer(uint64 matchId, address player) external view returns (bool isPlayer);

    function abortMatch(uint64 matchId) external;
    function endMatch(uint64 matchId) external;
    function findMatch(
        address player,
        address token,
        uint256 entry,
        uint8 playerNumber
    ) external payable returns (uint64 matchId);
    function setScore(
        uint64 matchId,
        address player,
        uint256 score,
        address bestPlayer
    ) external;
}
