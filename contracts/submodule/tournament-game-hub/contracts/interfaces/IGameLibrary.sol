// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IGameLibrary {
    struct GameData {
        string name;
        uint256 defaultTicketPrice;
        uint40 defaultAdditionalDuration;
        uint8 defaultFeePercentage;
    }

    event GameDefaultAdditionalDurationUpdate(address indexed gameAddress, uint40 newValue);
    event GameDefaultFeePercentageUpdate(address indexed gameAddress, uint8 newValue);
    event GameDefaultTicketPriceUpdate(address indexed gameAddress, uint256 newValue);
    event GameNameUpdate(address indexed gameAddress, string newValue);

    event GameRegistration(
        address indexed gameAddress,
        string name,
        uint256 defaultTicketPrice,
        uint40 defaultAdditionalDuration,
        uint8 defaultFeePercentage
    );
    event GameRemoval(address indexed gameAddress);

    error GameAlreadyRegistered();
    error InvalidParams();
    error NoRegisteredGame();
    error UnregisteredGame();

    function version() external pure returns (string memory version);

    function getGameNumber() external view returns (uint256 gameNumber);
    function getRegisteredGames() external view returns (address[] memory registeredGames);
    function getGame(address _gameAddress) external view returns (GameData memory game);
    function getRandomGameAddress() external view returns (address gameAddress);
}
