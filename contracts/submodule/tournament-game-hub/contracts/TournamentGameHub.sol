// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {Heap} from "./libraries/Heap.sol";
import {Set} from "./libraries/Set.sol";
import {Signature} from "./libraries/Signature.sol";

import {IAddressComparator} from "./interfaces/IAddressComparator.sol";
import {IAlphaKeysFactory} from "./interfaces/IAlphaKeysFactory.sol";
import {IGameLibrary} from "./interfaces/IGameLibrary.sol";
import {ITournamentGameHub} from "./interfaces/ITournamentGameHub.sol";

abstract contract TournamentGameHubStorage is ITournamentGameHub {
    struct PotData {
        mapping(address => PlayerData) players;
        // linked list of top players' addresses ordered by ascending score and descending lastSubmission
        mapping(address => address) topPlayers;
        address alpha;
        uint40 endAt;
        uint40 additionalDuration;
        uint16 topPlayerCount;
        address gameAddress;
        uint48 submissionCount;
        uint16 rewardConfigId;
        uint8 feePercentage;
        uint8 alphaFeePercentage;
        bool isOpening;
        uint256 value;
        uint256 ticketPrice;
        uint256 balanceRequirement;
        address topPlayersHead;
        address creator;
        address moderator;
    }

    // each config is an array of reward portions whose total value not exceeding PORTION_BASE (10000)
    mapping(uint16 => uint256[]) public rewardConfigs;
    mapping(address => uint64) public alphaLatestPotIds;
    mapping(address => uint256) public nonces;
    mapping(uint64 => PotData) public pots;
    mapping(uint64 => Heap.AddressHeap) internal potSecondaryPlayers;
    Set.AddressSet internal moderators;

    uint256 public defaultBalanceRequirement;
    address public token;
    uint64 public potNumber;
    uint16 public rewardConfigNumber;
    uint8 public alphaFeePercentage;
    bool public potCreationLock;
    address public treasury;
    uint32 public moderatorPivot;
    address public gameLibrary;
    address public alphaKeysFactory;

    uint256[50] private __gap;
}

contract TournamentGameHub is
TournamentGameHubStorage,
IAddressComparator,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Set for Set.AddressSet;
    using Heap for Heap.AddressHeap;

    address constant private ADDRESS_ZERO = address(0);
    uint256 constant public PORTION_BASE = 10000;

    modifier whenLatestPotOfAlphaIsOpening(address _alpha) {
        if (!pots[alphaLatestPotIds[_alpha]].isOpening) revert LatestPotOfAlphaIsNotOpening();
        _;
    }

    modifier whenLatestPotOfAlphaIsNotOpening(address _alpha) {
        if (pots[alphaLatestPotIds[_alpha]].isOpening) revert LatestPotOfAlphaIsOpening();
        _;
    }

    function initialize(
        address _token,
        address _treasury,
        address _gameLibrary,
        address _alphaKeysFactory,
        uint8 _alphaFeePercentage,
        uint256 _defaultBalanceRequirement,
        uint256[] calldata _defaultRewardPortions,
        address[] calldata _moderators
    ) external initializer {
        unchecked {
            if (_alphaFeePercentage > 100) revert InvalidParams();

            __Ownable_init();
            __Pausable_init();
            __ReentrancyGuard_init();

            token = _token;
            treasury = _treasury;
            gameLibrary = _gameLibrary;
            alphaKeysFactory = _alphaKeysFactory;
            alphaFeePercentage = _alphaFeePercentage;
            defaultBalanceRequirement = _defaultBalanceRequirement;

            uint256 rewardLimit = _defaultRewardPortions.length;
            if (rewardLimit == 0) revert InvalidParams();

            uint256 totalPortion = 0;
            for (uint256 i = 0; i < rewardLimit; ++i) {
                totalPortion += _defaultRewardPortions[i];
            }
            if (totalPortion > PORTION_BASE) revert InvalidParams();

            uint16 rewardConfigId = rewardConfigNumber = 1;
            rewardConfigs[rewardConfigId] = _defaultRewardPortions;

            uint256 moderatorNumber = _moderators.length;
            if (moderatorNumber == 0) revert InvalidParams();
            for (uint256 i = 0; i < moderatorNumber; ++i) {
                moderators.insert(_moderators[i]);
            }

            emit TokenUpdate(_token);
            emit TreasuryUpdate(_treasury);
            emit GameLibraryUpdate(_gameLibrary);
            emit AlphaKeysFactoryUpdate(_alphaKeysFactory);
            emit AlphaFeePercentageUpdate(_alphaFeePercentage);
            emit DefaultBalanceRequirementUpdate(_defaultBalanceRequirement);
            emit NewRewardConfig(rewardConfigId, rewardLimit);
            emit ModeratorsRegistration(moderatorNumber);
        }
    }

    function version() external pure returns (string memory) {
        return "v1.0.0";
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function increasePotNumber(uint64 _potNumber) external onlyOwner {
        if (_potNumber <= potNumber) revert InvalidParams();
        potNumber = _potNumber;
        emit PotNumberIncrement(_potNumber);
    }

    function updateToken(address _token) external onlyOwner {
        token = _token;
        emit TokenUpdate(_token);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdate(_treasury);
    }

    function updateGameLibrary(address _gameLibrary) external onlyOwner {
        gameLibrary = _gameLibrary;
        emit GameLibraryUpdate(_gameLibrary);
    }

    function updateAlphaKeysFactory(address _alphaKeysFactory) external onlyOwner {
        alphaKeysFactory = _alphaKeysFactory;
        emit AlphaKeysFactoryUpdate(_alphaKeysFactory);
    }

    function updateAlphaFeePercentage(uint8 _alphaFeePercentage) external onlyOwner {
        if (_alphaFeePercentage > 100) revert InvalidParams();
        alphaFeePercentage = _alphaFeePercentage;
        emit AlphaFeePercentageUpdate(_alphaFeePercentage);
    }

    function updateDefaultBalanceRequirement(uint256 _defaultBalanceRequirement) external onlyOwner {
        defaultBalanceRequirement = _defaultBalanceRequirement;
        emit DefaultBalanceRequirementUpdate(_defaultBalanceRequirement);
    }

    function addNewRewardConfig(uint256[] calldata _rewardPortions) external {
        unchecked {
            uint256 rewardLimit = _rewardPortions.length;
            if (rewardLimit == 0) revert InvalidParams();

            uint256 totalPortion = 0;
            for (uint256 i = 0; i < rewardLimit; ++i) {
                totalPortion += _rewardPortions[i];
            }
            if (totalPortion > PORTION_BASE) revert InvalidParams();

            uint16 rewardConfigId = ++rewardConfigNumber;
            rewardConfigs[rewardConfigId] = _rewardPortions;

            emit NewRewardConfig(rewardConfigId, rewardLimit);
        }
    }

    function registerModerators(address[] calldata _moderators) external onlyOwner {
        uint256 moderatorNumber = _moderators.length;
        unchecked {
            for (uint256 i = 0; i < moderatorNumber; ++i) {
                moderators.insert(_moderators[i]);
            }
        }
        emit ModeratorsRegistration(moderatorNumber);
    }

    function unregisterModerators(address[] calldata _moderators) external onlyOwner {
        uint256 moderatorNumber = _moderators.length;
        unchecked {
            for (uint256 i = 0; i < moderatorNumber; ++i) {
                moderators.erase(_moderators[i]);
            }
        }
        if (moderatorPivot >= moderators.size()) moderatorPivot = 0;
        emit ModeratorsUnregistration(moderatorNumber);
    }

    function getModerators() external view returns (address[] memory) {
        return moderators.values;
    }

    function getRewardConfig(uint16 _rewardConfigId) external view returns (uint256[] memory) {
        return rewardConfigs[_rewardConfigId];
    }

    function getGameData(address _gameAddress) external view returns (IGameLibrary.GameData memory) {
        return IGameLibrary(gameLibrary).getGame(_gameAddress);
    }

    function getPlayerData(uint64 _potId, address _player) external view returns (PlayerData memory) {
        return pots[_potId].players[_player];
    }

    function getPotDistributions(uint64 _potId) public view returns (
        uint256,
        uint256,
        address[] memory,
        uint256[] memory
    ) {
        unchecked {
            PotData storage potData = pots[_potId];

            uint256[] memory rewardPortions = rewardConfigs[potData.rewardConfigId];
            uint256 topPlayerCount = potData.topPlayerCount;
            address[] memory topPlayers = new address[](topPlayerCount);
            uint256[] memory rewards = new uint256[](topPlayerCount);

            address player = potData.topPlayersHead;
            uint256 totalReward;
            int256 pivot = int256(topPlayerCount) - 1;
            uint256 value = potData.value;
            uint256 temp = value / PORTION_BASE;
            for (uint256 i = 0; i < topPlayerCount; ++i) {
                topPlayers[i] = player;
                uint256 reward = temp * rewardPortions[uint256(pivot--)];
                rewards[i] = reward;
                totalReward += reward;
                player = potData.topPlayers[player];
            }

            return (totalReward, value - totalReward, topPlayers, rewards);
        }
    }

    function getLatestPotIdOfAlpha(address _alpha) external view returns (uint64) {
        return alphaLatestPotIds[_alpha];
    }

    function getLatestPotGameOfAlpha(address _alpha) external view returns (address) {
        return pots[alphaLatestPotIds[_alpha]].gameAddress;
    }

    function getLatestPotInfoOfAlpha(address _alpha) external view returns (
        uint64,
        uint256, uint256, uint256,
        address, address, address, address,
        uint48, uint40, uint40, uint16, uint16, uint8, uint8, bool
    ) {
        uint64 potId = alphaLatestPotIds[_alpha];
        PotData storage potData = pots[potId];
        return (
            potId,
            potData.value,
            potData.ticketPrice,
            potData.balanceRequirement,
            potData.alpha,
            potData.gameAddress,
            potData.creator,
            potData.moderator,
            potData.submissionCount,
            potData.endAt,
            potData.additionalDuration,
            potData.rewardConfigId,
            potData.topPlayerCount,
            potData.feePercentage,
            potData.alphaFeePercentage,
            potData.isOpening
        );
    }

    function isLatestPotOfAlphaEnded(address _alpha) external view returns (bool) {
        return pots[alphaLatestPotIds[_alpha]].endAt < block.timestamp;
    }

    function isLatestPotOfAlphaCloseable(address _alpha) external view returns (bool) {
        uint64 potId = alphaLatestPotIds[_alpha];
        if (potId == 0) return false;
        PotData storage potData = pots[potId];
        return potData.endAt < block.timestamp && potData.isOpening;
    }

    function isPlayerQualified(uint64 _potId, address _player) external view returns (bool) {
        address alpha = pots[_potId].alpha;
        return IAlphaKeysFactory(alphaKeysFactory).getKeysPlayer(alpha) != ADDRESS_ZERO
            && IERC20Upgradeable(alpha).balanceOf(_player) >= pots[_potId].balanceRequirement;
    }

    function compare(address _player1, address _player2) external view returns (bool) {
        uint64 potId = potNumber;
        PlayerData memory potPlayerData1 = pots[potId].players[_player1];
        PlayerData memory potPlayerData2 = pots[potId].players[_player2];
        if (potPlayerData1.score > potPlayerData2.score) return true;
        if (potPlayerData1.score == potPlayerData2.score) {
            return potPlayerData1.lastSubmission < potPlayerData2.lastSubmission;
        }
        return false;
    }

    function lockPotCreation() external onlyOwner {
        potCreationLock = true;
        emit PotCreationLock();
    }

    function unlockPotCreation() external onlyOwner {
        potCreationLock = false;
        emit PotCreationUnlock();
    }

    function _createPot(
        address _creator,
        address _alpha,
        address _gameAddress,
        uint256 _ticketPrice,
        uint8 _feePercentage,
        uint40 _initialDuration,
        uint40 _additionalDuration,
        uint256 _initialValue,
        uint256 _balanceRequirement,
        uint16 _rewardConfigId
    ) private nonReentrant {
        if (potCreationLock) revert PotCreationLocked();

        address alphaOwner = IAlphaKeysFactory(alphaKeysFactory).getKeysPlayer(_alpha);
        if (alphaOwner == ADDRESS_ZERO
            || (_creator != alphaOwner && IERC20Upgradeable(_alpha).balanceOf(_creator) == 0)) {
            revert InvalidAlpha();
        }

        if (_initialDuration == 0
            || _rewardConfigId == 0
            || _rewardConfigId > rewardConfigNumber) revert InvalidParams();

        IGameLibrary gameLibraryContract = IGameLibrary(gameLibrary);
        if (_gameAddress == ADDRESS_ZERO) {
            _gameAddress = gameLibraryContract.getRandomGameAddress();
        }
        IGameLibrary.GameData memory gameData = gameLibraryContract.getGame(_gameAddress);

        if (moderators.isEmpty()) revert NoRegisteredModerator();

        address moderator;
        unchecked {
            moderator = moderators.values[moderatorPivot++];
        }

        if (moderatorPivot == moderators.size()) moderatorPivot = 0;

        if (_ticketPrice == 0) _ticketPrice = gameData.defaultTicketPrice;
        if (_feePercentage == 0) _feePercentage = gameData.defaultFeePercentage;
        if (_additionalDuration == 0) _additionalDuration = gameData.defaultAdditionalDuration;
        if (_balanceRequirement == 0) _balanceRequirement = defaultBalanceRequirement;

        if (_feePercentage + alphaFeePercentage > 100) revert ConflictedPercentage();

        uint64 potId;
        unchecked {
            potId = ++potNumber;
        }

        PotData storage potData = pots[potId];

        potData.creator = _creator;
        potData.alpha = _alpha;
        potData.gameAddress = _gameAddress;
        potData.ticketPrice = _ticketPrice;
        potData.value = _initialValue;
        potData.balanceRequirement = _balanceRequirement;
        potData.rewardConfigId = _rewardConfigId;
        potData.feePercentage = _feePercentage;
        potData.additionalDuration = _additionalDuration;

        potData.alphaFeePercentage = alphaFeePercentage;
        potData.moderator = moderator;
        potData.endAt = uint40(block.timestamp + _initialDuration);
        potData.isOpening = true;

        potSecondaryPlayers[potId].comparator = address(this);

        alphaLatestPotIds[_alpha] = potId;

        IERC20Upgradeable(token).safeTransferFrom(_creator, address(this), _initialValue);

        emit PotCreation(
            potId,
            _creator,
            _alpha,
            _gameAddress,
            _ticketPrice,
            _feePercentage,
            _initialDuration,
            _initialValue,
            _balanceRequirement,
            _rewardConfigId
        );
    }

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
    ) external whenLatestPotOfAlphaIsNotOpening(_alpha) whenNotPaused {
        _createPot(
            msg.sender,
            _alpha,
            _gameAddress,
            _ticketPrice,
            _feePercentage,
            _initialDuration,
            _additionalDuration,
            _initialValue,
            _balanceRequirement,
            _rewardConfigId
        );
    }

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
    ) external whenLatestPotOfAlphaIsNotOpening(_alpha) whenNotPaused {
        if (!Signature.verifyEthSignature(
            _creator,
            keccak256(abi.encodePacked(
                address(this),
                nonces[_creator]++,
                _alpha,
                _gameAddress,
                _ticketPrice,
                _initialDuration,
                _initialValue,
                _balanceRequirement,
                _rewardConfigId
            )),
            _signature
        )) {
            revert InvalidSignature();
        }

        _createPot(
            _creator,
            _alpha,
            _gameAddress,
            _ticketPrice,
            _feePercentage,
            _initialDuration,
            _additionalDuration,
            _initialValue,
            _balanceRequirement,
            _rewardConfigId
        );
    }

    function raisePot(uint64 _potId, uint256 _value)
    external nonReentrant whenNotPaused {
        unchecked {
            if (pots[_potId].isOpening) {
                pots[_potId].value += _value;
                IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), _value);
            } else revert PotEnded();
            emit PotRaise(_potId, msg.sender, _value);
        }
    }

    function buyTicket(uint64 _potId, address _player, bytes calldata _signature)
    external nonReentrant whenNotPaused {
        unchecked {
            if (!Signature.verifyEthSignature(
                _player,
                keccak256(abi.encodePacked(
                    address(this),
                    _potId,
                    _player,
                    nonces[_player]++
                )),
                _signature
            )) {
                revert InvalidSignature();
            }

            PotData storage potData = pots[_potId];
            if (potData.endAt < block.timestamp) revert PotEnded();

            address alpha = potData.alpha;
            address alphaOwner = IAlphaKeysFactory(alphaKeysFactory).getKeysPlayer(alpha);
            if (_player != alphaOwner && IERC20Upgradeable(alpha).balanceOf(_player) < potData.balanceRequirement) {
                revert Unauthorized();
            }

            PlayerData storage potPlayerData = potData.players[_player];
            if (potPlayerData.hasTicket) revert AlreadyHavingATicket();
            potPlayerData.hasTicket = true;

            uint256 value = potData.ticketPrice;
            uint256 temp = value / 100;
            uint256 fee = temp * potData.feePercentage;
            uint256 alphaFee = temp * potData.alphaFeePercentage;

            potData.value += value - fee - alphaFee;

            if (potData.ticketPrice > 0) {
                IERC20Upgradeable tokenContract = IERC20Upgradeable(token);
                tokenContract.safeTransferFrom(_player, address(this), value);
                tokenContract.safeTransfer(treasury, fee);
                tokenContract.safeTransfer(alphaOwner, alphaFee);
            }

            emit TicketBuy(_potId, _player);
        }
    }

    function submitScore(uint64 _potId, address _player, int256 _score)
    external whenNotPaused {
        unchecked {
            PotData storage potData = pots[_potId];
            if (potData.gameAddress != msg.sender) revert Unauthorized();
            if (potData.endAt < block.timestamp) revert PotEnded();

            mapping(address => PlayerData) storage players = potData.players;
            PlayerData storage playerData = players[_player];
            if (!playerData.hasTicket) revert NoTicket();
            playerData.hasTicket = false;
            playerData.usedTickets++;
            Tier tier = playerData.tier;

            if (tier == Tier.NON_CANDIDATE || _score > playerData.score) {
                playerData.score = _score;
                playerData.lastSubmission = ++potData.submissionCount;

                if (tier == Tier.TOP_TIER) {
                    mapping(address => address) storage topPlayers = potData.topPlayers;
                    address pivotPlayer = potData.topPlayersHead;

                    if (pivotPlayer == _player) {
                        // Remove the player when being head of the linked list
                        address nextPlayer = topPlayers[pivotPlayer];
                        potData.topPlayersHead = nextPlayer;
                        pivotPlayer = nextPlayer;
                    }

                    if (pivotPlayer == ADDRESS_ZERO || _score <= players[pivotPlayer].score) {
                        // Set the player address as head of the linked list
                        topPlayers[_player] = pivotPlayer;
                        potData.topPlayersHead = _player;
                    } else {
                        while (true) {
                            address nextPlayer = topPlayers[pivotPlayer];
                            if (nextPlayer == _player) {
                                // Remove the player from the linked list to look for its new position
                                nextPlayer = topPlayers[nextPlayer];
                                topPlayers[pivotPlayer] = nextPlayer;
                            }

                            if (nextPlayer == ADDRESS_ZERO || _score <= players[nextPlayer].score) {
                                // Insert the player into the linked list
                                topPlayers[pivotPlayer] = _player;
                                topPlayers[_player] = nextPlayer;
                                pivotPlayer = nextPlayer;
                                break;
                            }

                            pivotPlayer = nextPlayer;
                        }
                    }

                    if (potData.topPlayerCount > rewardConfigs[potData.rewardConfigId].length) {
                        // When reward limit exceeded, drop the head of the linked list onto the heap
                        pivotPlayer = potData.topPlayersHead;
                        potSecondaryPlayers[_potId].push(pivotPlayer);
                        players[pivotPlayer].tier = Tier.SECONDARY_TIER;
                        potData.topPlayersHead = topPlayers[potData.topPlayersHead];
                    }

                    if (pivotPlayer == ADDRESS_ZERO) {
                        // Increase duration when there is a player actively becomes the best player.
                        uint256 extendedTimestamp = block.timestamp + potData.additionalDuration;
                        if (potData.endAt < extendedTimestamp) {
                            potData.endAt = uint40(extendedTimestamp);
                        }
                    }
                } else if (tier == Tier.SECONDARY_TIER) {
                    Heap.AddressHeap storage secondaryPlayers = potSecondaryPlayers[_potId];
                    mapping(address => address) storage topPlayers = potData.topPlayers;
                    address pivotPlayer = potData.topPlayersHead;
                    if (_score > players[pivotPlayer].score) {
                        secondaryPlayers.remove(_player);
                        // Drop the head of the linked list onto the heap
                        secondaryPlayers.push(pivotPlayer);
                        players[pivotPlayer].tier = Tier.SECONDARY_TIER;

                        pivotPlayer = topPlayers[potData.topPlayersHead];
                        potData.topPlayersHead = pivotPlayer;

                        if (pivotPlayer == ADDRESS_ZERO || _score <= players[pivotPlayer].score) {
                            // Set the player address as head of the linked list
                            topPlayers[_player] = pivotPlayer;
                            potData.topPlayersHead = _player;
                        } else {
                            while (true) {
                                address nextPlayer = topPlayers[pivotPlayer];

                                if (nextPlayer == ADDRESS_ZERO || _score <= players[nextPlayer].score) {
                                    // Insert the player into linked list
                                    topPlayers[pivotPlayer] = _player;
                                    topPlayers[_player] = nextPlayer;
                                    pivotPlayer = nextPlayer;
                                    break;
                                }

                                pivotPlayer = nextPlayer;
                            }
                        }

                        if (pivotPlayer == ADDRESS_ZERO) {
                            // Increase duration when there is a player actively becomes the best player.
                            uint256 extendedTimestamp = block.timestamp + potData.additionalDuration;
                            if (potData.endAt < extendedTimestamp) {
                                potData.endAt = uint40(extendedTimestamp);
                            }
                        }

                        playerData.tier = Tier.TOP_TIER;
                    } else {
                        // Update data for the player in heap
                        secondaryPlayers.up(_player);
                    }
                } else {
                    address pivotPlayer = potData.topPlayersHead;
                    uint256 rewardLimit = rewardConfigs[potData.rewardConfigId].length;
                    uint256 topPlayerCount = potData.topPlayerCount;
                    if (topPlayerCount < rewardLimit || _score > players[pivotPlayer].score) {
                        // New player belongs to top players
                        mapping(address => address) storage topPlayers = potData.topPlayers;
                        if (pivotPlayer == ADDRESS_ZERO || _score <= players[pivotPlayer].score) {
                            topPlayers[_player] = pivotPlayer;
                            potData.topPlayersHead = _player;
                            topPlayerCount++;
                        } else {
                            while (true) {
                                address nextPlayer = topPlayers[pivotPlayer];

                                if (nextPlayer == ADDRESS_ZERO || _score <= players[nextPlayer].score) {
                                    // Insert the player into linked list
                                    topPlayers[pivotPlayer] = _player;
                                    topPlayers[_player] = nextPlayer;
                                    topPlayerCount++;
                                    pivotPlayer = nextPlayer;
                                    break;
                                }

                                pivotPlayer = nextPlayer;
                            }
                        }

                        if (pivotPlayer == ADDRESS_ZERO) {
                            // Increase duration when there is a player actively becomes the best player.
                            uint256 extendedTimestamp = block.timestamp + potData.additionalDuration;
                            if (potData.endAt < extendedTimestamp) {
                                potData.endAt = uint40(extendedTimestamp);
                            }
                        }

                        if (topPlayerCount > rewardLimit) {
                            // Drop the head of the linked list onto the heap
                            topPlayerCount--;
                            pivotPlayer = potData.topPlayersHead;
                            potSecondaryPlayers[_potId].push(pivotPlayer);
                            players[pivotPlayer].tier = Tier.SECONDARY_TIER;
                            potData.topPlayersHead = topPlayers[potData.topPlayersHead];
                        }

                        potData.topPlayerCount = uint16(topPlayerCount);
                        playerData.tier = Tier.TOP_TIER;
                    } else {
                        // New player belongs to secondary players
                        potSecondaryPlayers[_potId].push(_player);
                        playerData.tier = Tier.SECONDARY_TIER;
                    }
                }
            }
            emit ScoreSubmission(_potId, potData.alpha, _player, _score);
        }
    }

    function _closePot(uint64 _potId) private nonReentrant {
        unchecked {
            PotData storage potData = pots[_potId];
            if (!potData.isOpening) revert PotAlreadyClosed();
            potData.isOpening = false;

            (uint256 totalReward, uint256 remainValue, , ) = getPotDistributions(_potId);

//            (
//                uint256 totalReward,
//                uint256 remainValue,
//                address[] memory topPlayers,
//                uint256[] memory rewards
//            ) = getPotDistributions(_potId);

//            uint256 rewardNumber = rewards.length;
//            IERC20Upgradeable tokenContract = IERC20Upgradeable(token);
//            for (uint256 i = 0; i < rewardNumber; ++i) {
//                tokenContract.safeTransfer(topPlayers[i], rewards[i]);
//            }
//
//            if (remainValue > 0) {
//                tokenContract.safeTransfer(potData.creator, remainValue);
//            }

            IERC20Upgradeable(token).safeTransfer(potData.moderator, potData.value);

            emit PotClosure(_potId, totalReward, remainValue);
        }
    }

    function closePot(uint64 _potId)
    external whenNotPaused {
        if (pots[_potId].endAt >= block.timestamp) revert PotNotEnded();
        _closePot(_potId);
    }

    function forceClosePot(uint64 _potId)
    external onlyOwner whenNotPaused {
        _closePot(_potId);
    }
}
