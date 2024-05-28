// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IAsyncGameHub {
    enum MatchPhase {
        NIL,
        PLAYING,
        ENDED,
        ABORTED
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
        uint8 playerNumber;
        MatchPhase phase;
        uint8 playerSubmissions;
        uint8 logicVersion;
        address token;
        address bestPlayer;
    }

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

    error FailedTransfer();
    error GameNotIntegrable();
    error InsufficientFunds();
    error InvalidMatchAborting();
    error InvalidMatchEnding();
    error InvalidMatchId();
    error InvalidParams();
    error InvalidScoreSetting();
    error NotPlayerOfTheMatch();
    error Unauthorized();

    function version() external pure returns (string memory);

    function feePercentage() external view returns (uint8);
    function gameLibrary() external view returns (address);
    function matchNumber() external view returns (uint64);
    function treasury() external view returns (address);

    function getAbortedMatches() external view returns (uint64[] memory);
    function getPlayerPlayingMatches(address player) external view returns (BriefMatchData[] memory);
    function getPlayerLatestUnfinishedMatches(address player) external view returns (BriefMatchData[] memory);
    function getPlayingMatches() external view returns (uint64[] memory);
    function getMatchPlayerAddresses(uint64 matchId) external view returns (address[] memory);
    function getMatchPlayers(uint64 matchId) external view returns (address[] memory, PlayerData[] memory);

    function isMatchEnded(uint64 _matchId) external view returns (bool);
    function isMatchEndable(uint64 _matchId) external view returns (bool);

    function findMatch(
        address player,
        address token,
        uint256 entry,
        uint8 playerNumber
    ) external payable returns (uint64) ;
    function endMatch(uint64 matchId) external;
    function setScore(
        uint64 matchId,
        address player,
        uint256 score
    ) external;
}
