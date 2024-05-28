// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IGameLibrary} from "./IGameLibrary.sol";

interface ITournamentGameHub {
    enum Tier {
        NON_CANDIDATE,
        TOP_TIER,
        SECONDARY_TIER
    }

    struct PlayerData {
        int256 score;
        uint48 lastSubmission;
        uint32 usedTickets;
        bool hasTicket;
        Tier tier;
    }

    event AlphaFeePercentageUpdate(uint8 newValue);
    event AlphaKeysFactoryUpdate(address newAddress);
    event DefaultBalanceRequirementUpdate(uint256 newValue);
    event GameLibraryUpdate(address newAddress);
    event TokenUpdate(address newAddress);
    event TreasuryUpdate(address newAddress);

    event NewRewardConfig(uint16 rewardConfigId, uint256 rewardLimit);

    event ModeratorsRegistration(uint256 registeredModeratorNumber);
    event ModeratorsUnregistration(uint256 unregisteredModeratorNumber);

    event PotClosure(uint64 indexed potId, uint256 totalReward, uint256 remainValue);
    event PotCreation(
        uint64 indexed potId,
        address creator,
        address indexed alpha,
        address indexed gameAddress,
        uint256 ticketPrice,
        uint8 feePercentage,
        uint40 initialDuration,
        uint256 intitialValue,
        uint256 balanceRequirement,
        uint32 rewardConfigId
    );
    event PotCreationLock();
    event PotCreationUnlock();
    event PotNumberIncrement(uint64 potNumber);
    event PotRaise(uint64 indexed potId, address raiser, uint256 value);

    event ScoreSubmission(
        uint64 indexed potId,
        address indexed alpha,
        address indexed player,
        int256 score
    );
    event TicketBuy(uint64 indexed potId, address buyer);

    error AlreadyHavingATicket();
    error ConflictedPercentage();
    error InvalidAlpha();
    error InvalidParams();
    error InvalidSignature();
    error LatestPotOfAlphaIsNotOpening();
    error LatestPotOfAlphaIsOpening();
    error NoRegisteredModerator();
    error NoTicket();
    error PotAlreadyClosed();
    error PotCreationLocked();
    error PotEnded();
    error PotNotEnded();
    error Unauthorized();

    function version() external pure returns (string memory version);

    function token() external view returns (address token);
    function treasury() external view returns (address treasury);
    function gameLibrary() external view returns (address gameLibrary);
    function alphaKeysFactory() external view returns (address alphaKeysFactory);

    function defaultBalanceRequirement() external view returns (uint256 defaultBalanceRequirement);
    function potNumber() external view returns (uint64 potNumber);
    function rewardConfigNumber() external view returns (uint16 rewardConfigNumber);
    function moderatorPivot() external view returns (uint32 moderatorPivot);
    function alphaFeePercentage() external view returns (uint8 alphaFeePercentage);
    function potCreationLock() external view returns (bool potCreationLock);

    function nonces(address _address) external view returns (uint256 nonce);
    function alphaLatestPotIds(address _alpha) external view returns (uint64 potId);

    function getModerators() external view returns (address[] memory moderators);
    function getRewardConfig(uint16 _rewardConfigId) external view returns (uint256[] memory rewardPortions);
    function getGameData(address _gameAddress) external view returns (IGameLibrary.GameData memory gameData);
    function getPlayerData(uint64 _potId, address _player) external view returns (PlayerData memory playerData);
    function getPotDistributions(uint64 _potId) external view returns (
        uint256 totalReward,
        uint256 remainValue,
        address[] memory topPlayers,
        uint256[] memory rewards
    );
    function getLatestPotGameOfAlpha(address _alpha) external view returns (address gameAddress);
    function getLatestPotInfoOfAlpha(address _alpha) external view returns (
        uint64 potId,
        uint256 value,
        uint256 ticketPrice,
        uint256 balanceRequirement,
        address alpha,
        address gameAddress,
        address creator,
        address moderator,
        uint48 submissionCount,
        uint40 endAt,
        uint40 additionalDuration,
        uint16 rewardConfigId,
        uint16 topPlayerCount,
        uint8 feePercentage,
        uint8 alphaFeePercentage,
        bool isOpening
    );
    function isLatestPotOfAlphaEnded(address _alpha) external view returns (bool ended);
    function isLatestPotOfAlphaCloseable(address _alpha) external view returns (bool closable);
    function isPlayerQualified(uint64 _potId, address _player) external view returns (bool qualified);

    function createPot(
        address _alpha,
        address _gameAddress,
        uint256 _ticketPrice,
        uint8 _feePercentage,
        uint40 _initialDuration,
        uint40 _additionalDuration,
        uint256 _initialValue,
        uint256 _balanceRequirement,
        uint16 _rewardConfigId
    ) external;
    function createPotWithSignature(
        address _creator,
        address _alpha,
        address _gameAddress,
        uint256 _ticketPrice,
        uint8 _feePercentage,
        uint40 _initialDuration,
        uint40 _additionalDuration,
        uint256 _initialValue,
        uint256 _balanceRequirement,
        uint16 _rewardConfigId,
        bytes calldata _signature
    ) external;
    function raisePot(uint64 _potId, uint256 _value) external;
    function buyTicket(uint64 _potId, address _player, bytes calldata _signature) external;
    function submitScore(uint64 _potId, address _player, int256 _score) external;
    function closePot(uint64 _potId) external;
}
