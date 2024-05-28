// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IGameLibrary} from "./interfaces/IGameLibrary.sol";

import {Set} from "./libraries/Set.sol";

import "hardhat/console.sol";

abstract contract GameLibraryStorage is IGameLibrary {
    mapping(address => GameData) public games;
    Set.AddressSet internal registeredGames;

    uint256[50] private __gap;
}

contract GameLibrary is GameLibraryStorage, OwnableUpgradeable {
    using Set for Set.AddressSet;

    modifier withRegisteredGame(address _gameAddress) {
        if (!registeredGames.hasValue(_gameAddress)) revert UnregisteredGame();
        _;
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    function version() external pure returns (string memory) {
        return "v0.0.1";
    }

    function updateGameName(address _gameAddress, string calldata _name)
    external onlyOwner withRegisteredGame(_gameAddress) {
        games[_gameAddress].name = _name;
        emit GameNameUpdate(_gameAddress, _name);
    }

    function updateGameDefaultAdditionalDuration(address _gameAddress, uint40 _defaultAdditionDuration)
    external onlyOwner withRegisteredGame(_gameAddress) {
        if (_defaultAdditionDuration == 0) revert InvalidParams();
        games[_gameAddress].defaultAdditionalDuration = _defaultAdditionDuration;
        emit GameDefaultAdditionalDurationUpdate(_gameAddress, _defaultAdditionDuration);
    }

    function updateGameDefaultFeePercentage(address _gameAddress, uint8 _defaultFeePercentage)
    external onlyOwner withRegisteredGame(_gameAddress) {
        if (_defaultFeePercentage > 100) revert InvalidParams();
        games[_gameAddress].defaultFeePercentage = _defaultFeePercentage;
        emit GameDefaultFeePercentageUpdate(_gameAddress, _defaultFeePercentage);
    }

    function updateGameDefaultTicketPrice(address _gameAddress, uint256 _defaultTicketPrice)
    external onlyOwner withRegisteredGame(_gameAddress) {
        if (_defaultTicketPrice == 0) revert InvalidParams();
        games[_gameAddress].defaultTicketPrice = _defaultTicketPrice;
        emit GameDefaultTicketPriceUpdate(_gameAddress, _defaultTicketPrice);
    }

    function getRegisteredGames() public view returns (address[] memory) {
        return registeredGames.values;
    }

    function registerGame(
        address _gameAddress,
        string calldata _name,
        uint256 _defaultTicketPrice,
        uint40 _defaultAdditionalDuration,
        uint8 _defaultFeePercentage
    ) external onlyOwner {
        if (registeredGames.hasValue(_gameAddress)) revert GameAlreadyRegistered();
        if (_defaultTicketPrice == 0 || _defaultFeePercentage > 100) revert InvalidParams();
        registeredGames.insert(_gameAddress);

        GameData storage gameData = games[_gameAddress];

        gameData.name = _name;
        gameData.defaultTicketPrice = _defaultTicketPrice;
        gameData.defaultAdditionalDuration = _defaultAdditionalDuration;
        gameData.defaultFeePercentage = _defaultFeePercentage;

        emit GameRegistration(
            _gameAddress,
            _name,
            _defaultTicketPrice,
            _defaultAdditionalDuration,
            _defaultFeePercentage
        );
    }

    function removeGame(address _gameAddress) external onlyOwner withRegisteredGame(_gameAddress) {
        registeredGames.erase(_gameAddress);
        emit GameRemoval(_gameAddress);
    }

    function getGameNumber() external view returns (uint256) {
        return registeredGames.size();
    }

    function getGame(address _gameAddress) external view withRegisteredGame(_gameAddress) returns (GameData memory) {
        return games[_gameAddress];
    }

    function getRandomGameAddress() external view returns (address) {
        unchecked {
            if (registeredGames.size() == 0) revert NoRegisteredGame();
            return registeredGames.values[
                uint256(keccak256(abi.encodePacked(
                    block.number,
                    block.timestamp,
                    blockhash(block.number)
                ))) % registeredGames.size()
            ];
        }
    }
}
