// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IJackpotGameHubMigratable {
    event PotRaise(uint64 indexed potId, address raiser, uint256 value);

    function raisePot(uint256 _value) external;
}

interface IJackpotGameHub is IJackpotGameHubMigratable {
    enum Tier {
        NON_CANDIDATE,
        TOP_TIER,
        SECONDARY_TIER
    }

    event Migration(address newAddress, uint256 value);

    event AlphaFactoryUpdate(address newAddress);
    event OperationFundUpdate(address newAddress);
    event OperationFundingPercentageUpdate(uint8 newValue);
    event PotNumberUpdate(uint64 newValue);
    event ReservePercentageUpdate(uint8 newValue);
    event TreasuryUpdate(address newAddress);

    event NewRewardConfig(uint16 rewardConfigId, uint256 rewardLimit);

    event GameAdditionalDurationUpdate(address indexed gameAddress, uint40 newValue);
    event GameDefaultTicketPriceUpdate(address indexed gameAddress, uint256 newValue);
    event GameFeePercentageUpdate(address indexed gameAddress, uint8 newValue);
    event GameNameUpdate(address indexed gameAddress, string newValue);

    event GameRegistration(
        address indexed gameAddress,
        string name,
        uint256 defaultTicketPrice,
        uint8 feePercentage,
        uint40 additionDuration
    );
    event GameRemoval(address indexed gameAddres);

    event PotClosure(
        uint64 indexed potId,
        uint256 totalReward,
        uint256 remainValue,
        uint256 rewardedAlphaNumber
    );
    event PotCreation(
        uint64 indexed potId,
        address indexed gameAddress,
        uint256 ticketPrice,
        uint40 initialDuration,
        uint256 value,
        uint256 qualificationThreshold,
        uint16 rewardConfigId
    );
    event ScoreSubmission(uint64 indexed potId, address indexed player, address indexed alpha, int256 score);
    event TicketBuy(uint64 indexed potId, address buyer);

    error AlreadyHavingATicket();
    error ConflictPercentages(address gameAddress);
    error GameAlreadyRegistered();
    error InvalidAlpha();
    error InvalidParams();
    error InvalidSignature();
    error NoPotIsOpening();
    error NoRegisteredGame();
    error NoTicket();
    error PotAlreadyClosed();
    error PotEnded();
    error PotIsOpening();
    error PotNotEnded();
    error Unauthorized();
    error UnregisteredGame();

    function version() external pure returns (string memory version);

    function potNumber() external view returns (uint64 potNumber);
    function alphaFactory() external view returns (address alphaFactory);
    function treasury() external view returns (address treasury);
    function operationFund() external view returns (address operationFund);
    function operationFundingPercentage() external view returns (uint8 operationFundingPercentage);
    function reservePercentage() external view returns (uint8 reservePercentage);
    function reservePot() external view returns (uint256 reservePot);

    function getGamePots(address _gameAddress) external view returns (uint64[] memory pots);
    function getLatestPotGame() external view returns (address game);
    function getLatestPotInfo() external view returns (
        uint64 potId,
        uint256 value,
        uint256 ticketPrice,
        uint256 qualificationThreshold,
        address game,
        uint40 endAt,
        uint40 additionalDuration,
        bool isOpening,
        uint8 feePercentage,
        uint8 operationFundingPercentage,
        uint8 reservePercentage,
        uint16 rewardConfigId,
        uint32 submissionCount,
        uint32 topAlphaCount
    );
    function getPlayer(address _player) external view returns (
        uint64 ticket,
        uint64 nonce
    );
    function getPotAlpha(uint64 _potId, address _alpha) external view returns (
        int256 score,
        uint32 lastSubmission,
        uint32 totalSubmission
    );
    function getPotAlphaPlayers(uint64 _potId, address _alpha) external view returns (address[] memory);
    function getPotAlphaPlayerSubmission(
        uint64 _potId,
        address _alpha,
        address _player
    )  external view returns (uint64);
    function getPotDistributions(uint64 _potId) external view returns (
        uint256 totalReward,
        uint256 remainValue,
        address[] memory rewardedAlphas,
        uint256[] memory alphaRewards,
        address[][] memory alphaPlayers,
        uint256[][] memory alphaPlayerRewards
    );
    function getRegisteredGames() external view returns (address[] memory games);
    function getRewardConfig(uint16 rewardConfigId) external view returns (uint256[] memory);

    function isLatestPotEnded() external view returns (bool ended);
    function isPlayerQualified(
        uint64 _potId,
        address _player,
        address _alpha
    ) external view returns (bool qualified);
    function hasTicket(address _player) external view returns (bool);

    function createPotOfRandomGame(
        uint256 _ticketPrice,
        uint40 _initialDuration,
        uint256 _initialValue,
        uint256 _qualificationThreshold,
        uint16 _rewardConfigId
    ) external;
    function createPotOfSpecificGame(
        address _gameAddress,
        uint256 _ticketPrice,
        uint40 _initialDuration,
        uint256 _initialValue,
        uint256 _qualificationThreshold,
        uint16 _rewardConfigId
    ) external;
    function buyTicket(address _player, bytes calldata _signature) external;
    function submitScore(
        address _player,
        address _alpha,
        int256 _score
    ) external;
    function closePot() external;
}
