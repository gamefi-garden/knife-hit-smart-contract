//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAsyncGameHub} from "./IAsyncGameHub.sol";
import {Signature} from "./Signature.sol";

abstract contract BaseAsyncMatchingGame is OwnableUpgradeable {
    address public asyncGameHubAddress;
    mapping(address => uint) noncePlayers; // player => nonce

    enum ErrorCode{
        None,
        InvalidGameAddress,
        InvalidSignature,
        InvalidMatchData,
        InvalidMatchId,
        GameSeedIsZero,
        DuplicateSubmissionHashes
    }

    error RevertErrorCode(ErrorCode);

    event GameHubAddressUpdated(address newAddress);
    event PlayerNonceGenerated(address indexed playerAddress, uint nonce);

    function initialize() public initializer(){
        __Ownable_init();
        onInitialized();
    }

    function onInitialized() virtual internal {
    }

    function version() virtual external pure returns (string memory);

    function updateAsyncGameHubAddress(address gameHubAddress) onlyOwner external {
        asyncGameHubAddress = gameHubAddress;
        emit GameHubAddressUpdated(gameHubAddress);
    }

    struct BriefPlayerMatchData {
        uint64 id;
        uint256 score;
    }
    
    function getPlayerNonce(address _player) public view returns (uint){
        return noncePlayers[_player] == 0 ? uint(keccak256(abi.encodePacked(_player, address(this)))) : noncePlayers[_player];
    }


    function getPlayingMatchInfoOf(address player) public view returns (
        uint64 matchId,
        address[] memory playerAddresses,
        address token,
        address bestPlayer,
        uint40 playingTimeLimit,
        uint8 playerNumber
    ) {
        IAsyncGameHub gameHub = IAsyncGameHub(asyncGameHubAddress);
        IAsyncGameHub.BriefMatchData[] memory playingMatches = gameHub.getPlayerLatestUnfinishedMatches(player);
        uint256 numOfPlayingMatches = playingMatches.length;
        if (numOfPlayingMatches != 0) {
            for (uint256 i = 0; i < numOfPlayingMatches; i++) {
                if (playingMatches[i].gameAddress == address(this)
                    && playingMatches[i].phase == IAsyncGameHub.MatchPhase.PLAYING) {
                    matchId = playingMatches[i].id;
                    playerAddresses = playingMatches[i].playerAddresses;
                    token = playingMatches[i].token;
                    bestPlayer = playingMatches[i].bestPlayer;
                    playingTimeLimit = playingMatches[i].playingTimeLimit;
                    playerNumber = playingMatches[i].playerNumber;
                    break;
                }
            }
        }

        return (matchId, playerAddresses, token, bestPlayer, playingTimeLimit, playerNumber);
    }
    function getPlayingHistory(address player) public view returns (
        IAsyncGameHub.BriefMatchData[] memory matchData
    ) {
          IAsyncGameHub gameHub = IAsyncGameHub(asyncGameHubAddress);
        return gameHub.getPlayerLatestUnfinishedMatches(player);
    }

    function findMatch(
        address token,
        uint256 entry,
        uint8 playerNumber
    ) external payable {
        IAsyncGameHub gameHub = IAsyncGameHub(asyncGameHubAddress);
        uint64 gameId = gameHub.findMatch{value: msg.value}(msg.sender, token, entry, playerNumber);
        (address[] memory playerAddresses,) = gameHub.getMatchPlayers(gameId);
        if (playerAddresses.length == 1) { //match created
            _onMatchCreated(gameId);
        } else {
            _onMatchJoined(gameId);
        }
    }

    function _setScore(uint64 matchId, uint256 score) internal {
        IAsyncGameHub gameHub = IAsyncGameHub(asyncGameHubAddress);
        gameHub.setScore(matchId,msg.sender,score);
    }


    function _verifySignatureAndGenNonce(address player, bytes memory rawdata, bytes calldata signature) internal {
        uint nonce = getPlayerNonce(player);
        bytes32 signedData = keccak256(abi.encodePacked(nonce, rawdata));
        if (!Signature.verifyEthSignature(player, signedData, signature)){
            revert RevertErrorCode(ErrorCode.InvalidSignature);
        }

        nonce = noncePlayers[player] = uint(keccak256(abi.encodePacked(player, nonce, block.timestamp)));
        emit PlayerNonceGenerated(player, nonce);
    }

    function _onMatchCreated(uint64 gameId) internal virtual {}
    function _onMatchJoined(uint64 gameId) internal virtual {}
}