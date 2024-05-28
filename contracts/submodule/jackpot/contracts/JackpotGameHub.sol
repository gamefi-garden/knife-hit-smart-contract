// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
// TODO: remove
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import {IAddressComparator} from "./interfaces/IAddressComparator.sol";
import {IAlphaKeysFactory} from "./interfaces/IAlphaKeysFactory.sol";
import {IJackpotGameHub, IJackpotGameHubMigratable} from "./interfaces/IJackpotGameHub.sol";

import {Heap} from "./libraries/Heap.sol";
import {Set} from "./libraries/Set.sol";
import {Signature} from "./libraries/Signature.sol";

abstract contract JackpotStorage is IJackpotGameHub {
    struct GameData {
        uint64[] pots;
        string name;
        uint256 defaultTicketPrice;
        uint40 additionalDuration;
        uint8 feePercentage;
    }

    struct PlayerData {
        uint64 ticket;
        uint64 nonce;
    }

    struct AlphaData {
        mapping(address => uint256) playerSubmissions;
        Set.AddressSet players;
        int256 totalScore;
        uint32 lastSubmission;
        uint32 totalSubmission;
        Tier tier;
    }

    struct PotData {
        mapping(address => AlphaData) alphas;
        mapping(address => address) topAlphas;
        uint256 value;
        uint256 ticketPrice;
        uint256 qualificationThreshold;
        address topAlphasHead;
        uint40 additionalDuration;
        uint32 topAlphaCount;
        uint8 feePercentage;
        uint8 operationFundingPercentage;
        uint8 reservePercentage;
        address game;
        uint40 endAt;
        uint32 submissionCount;
        uint16 rewardConfigId;
        bool isOpening;
    }

    mapping(uint16 => uint256[]) public rewardConfigs;
    mapping(address => PlayerData) public players;
    mapping(address => GameData) public games;
    mapping(uint64 => PotData) public pots;
    mapping(uint64 => Heap.AddressHeap) internal potSecondaryAlphas;
    Set.AddressSet internal registeredGames;

    address public token;
    address public treasury;
    address public operationFund;
    uint64 public potNumber;
    uint16 public rewardConfigNumber;
    uint8 public operationFundingPercentage;
    uint8 public reservePercentage;
    uint256 public reservePot;
    uint256 public alphaQualificationThreshold;
    address public alphaFactory;

    uint256[50] private __gap;
}

contract JackpotGameHub is
IAddressComparator,
JackpotStorage,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Heap for Heap.AddressHeap;
    using Set for Set.AddressSet;

    address constant private ADDRESS_ZERO = address(0);
    uint256 constant public PORTION_BASE = 10000;

    modifier whenPotIsOpening() {
        if (!pots[potNumber].isOpening) revert NoPotIsOpening();
        _;
    }

    modifier whenNoPotIsOpening() {
        if (pots[potNumber].isOpening) revert PotIsOpening();
        _;
    }

    modifier onlyRegisteredGame(address _gameAddress) {
        if (!registeredGames.hasValue(_gameAddress)) revert UnregisteredGame();
        _;
    }

    function initialize(
        address _token,
        address _alphaFactory,
        address _treasury,
        address _operationFund,
        uint8 _operationFundingPercentage,
        uint8 _reservePercentage,
        uint256[] calldata _rewardPortions
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        token = _token;
        alphaFactory = _alphaFactory;
        treasury = _treasury;
        operationFund = _operationFund;
        operationFundingPercentage = _operationFundingPercentage;
        reservePercentage = _reservePercentage;

        uint256 rewardLimit = _rewardPortions.length;
        uint256 totalPortion = 0;

        for (uint256 i = 0; i < rewardLimit; ++i) {
            totalPortion += _rewardPortions[i];
        }
        if (totalPortion > PORTION_BASE) revert InvalidParams();

        rewardConfigNumber = 1;
        rewardConfigs[1] = _rewardPortions;

        emit AlphaFactoryUpdate(_alphaFactory);
        emit TreasuryUpdate(_treasury);
        emit OperationFundUpdate(_operationFund);
        emit OperationFundingPercentageUpdate(_operationFundingPercentage);
        emit ReservePercentageUpdate(_reservePercentage);
        emit NewRewardConfig(1, rewardLimit);
    }

    function version() external pure returns (string memory) {
        return "v1.0.1";
    }

    function pause() virtual external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() virtual external onlyOwner whenPaused {
        _unpause();
    }

    function migrate(address _newContractAddress)
    external nonReentrant onlyOwner whenNoPotIsOpening {
        uint256 value = reservePot;
        reservePot = 0;
        IERC20Upgradeable(token).approve(_newContractAddress, value);
        IJackpotGameHubMigratable(_newContractAddress).raisePot(value);
        emit Migration(_newContractAddress, value);
    }

    function updateAlphaFactory(address _alphaFactory) external onlyOwner {
        alphaFactory = _alphaFactory;
        emit AlphaFactoryUpdate(_alphaFactory);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryUpdate(_treasury);
    }

    function updateOperationFund(address _operationFund) external onlyOwner {
        operationFund = _operationFund;
        emit OperationFundUpdate(_operationFund);
    }

    function updateOperationFundingPercentage(uint8 _operationFundingPercentage) external onlyOwner {
        operationFundingPercentage = _operationFundingPercentage;
        emit OperationFundingPercentageUpdate(_operationFundingPercentage);
    }

    function updateReservePercentage(uint8 _reservePercentage) external onlyOwner {
        if (_reservePercentage > 100) revert InvalidParams();
        reservePercentage = _reservePercentage;
        emit ReservePercentageUpdate(_reservePercentage);
    }

    function updatePotNumber(uint64 _potNumber) external onlyOwner whenNoPotIsOpening {
        if (_potNumber < potNumber) revert InvalidParams();
        potNumber = _potNumber;
        emit PotNumberUpdate(_potNumber);
    }

    function updateGameAdditionalDuration(address _gameAddress, uint40 _additionDuration)
    external onlyOwner onlyRegisteredGame(_gameAddress) {
        if (_additionDuration == 0) revert InvalidParams();
        games[_gameAddress].additionalDuration = _additionDuration;
        emit GameAdditionalDurationUpdate(_gameAddress, _additionDuration);
    }

    function updateGameName(address _gameAddress, string calldata _name)
    external onlyOwner onlyRegisteredGame(_gameAddress) {
        games[_gameAddress].name = _name;
        emit GameNameUpdate(_gameAddress, _name);
    }

    function updateGameDefaultTicketPrice(address _gameAddress, uint256 _defaultTicketPrice)
    external onlyOwner onlyRegisteredGame(_gameAddress) {
        if (_defaultTicketPrice == 0) revert InvalidParams();
        games[_gameAddress].defaultTicketPrice = _defaultTicketPrice;
        emit GameDefaultTicketPriceUpdate(_gameAddress, _defaultTicketPrice);
    }

    function updateGameFeePercentage(address _gameAddress, uint8 _feePercentage)
    external onlyOwner onlyRegisteredGame(_gameAddress) {
        if (_feePercentage > 100) revert InvalidParams();
        games[_gameAddress].feePercentage = _feePercentage;
        emit GameFeePercentageUpdate(_gameAddress, _feePercentage);
    }

    function addNewRewardConfig(uint256[] calldata _rewardPortions) external onlyOwner {
        uint256 rewardLimit = _rewardPortions.length;
        uint256 totalPortion = 0;
        for (uint256 i = 0; i < rewardLimit; ++i) {
            totalPortion += _rewardPortions[i];
        }
        if (totalPortion > PORTION_BASE) revert InvalidParams();

        uint16 rewardConfigId = ++rewardConfigNumber;
        rewardConfigs[rewardConfigId] = _rewardPortions;

        emit NewRewardConfig(rewardConfigId, rewardLimit);
    }

    function getRewardConfig(uint16 rewardConfigId) external view returns (uint256[] memory) {
        if (rewardConfigId == 0 || rewardConfigId > rewardConfigNumber) revert InvalidParams();
        return rewardConfigs[rewardConfigId];
    }

    function getRegisteredGames() public view returns (address[] memory) {
        return registeredGames.values;
    }

    function getGamePots(address _gameAddress) external view returns (uint64[] memory) {
        return games[_gameAddress].pots;
    }

    function getPlayer(address _player) external view returns (uint64, uint64) {
        PlayerData storage playerData = players[_player];
        return (
            playerData.ticket,
            playerData.nonce
        );
    }

    function getPotAlpha(uint64 _potId, address _alpha) external view returns (int256, uint32, uint32) {
        AlphaData storage alphaData = pots[_potId].alphas[_alpha];
        return (
            alphaData.totalScore,
            alphaData.lastSubmission,
            alphaData.totalSubmission
        );
    }

    function getPotAlphaPlayers(uint64 _potId, address _alpha) external view returns (address[] memory) {
        return pots[_potId].alphas[_alpha].players.values;
    }

    function getPotAlphaPlayerSubmission(
        uint64 _potId,
        address _alpha,
        address _player
    ) external view returns (uint64) {
        return uint64(pots[_potId].alphas[_alpha].playerSubmissions[_player]);
    }

    function getAlphaRewards(AlphaData storage _alphaData, uint256 _reward)
    private view returns (address[] memory, uint256[] memory, uint256) {
        address[] memory alphaPlayers = _alphaData.players.values;
        uint256 alphaPlayerNumber = alphaPlayers.length;
        uint256[] memory alphaPlayerRewards = new uint256[](alphaPlayerNumber);

        uint256 dust = _reward;
        unchecked {
            uint256 temp = _reward / _alphaData.totalSubmission;
            mapping(address => uint256) storage playerSubmissions = _alphaData.playerSubmissions;
            for (uint256 i = 0; i < alphaPlayerNumber; ++i) {
                uint256 reward = temp * playerSubmissions[alphaPlayers[i]];
                alphaPlayerRewards[i] = reward;
                dust -= reward;
            }
        }
        return (alphaPlayers, alphaPlayerRewards, dust);
    }

    function getPotDistributions(uint64 _potId) public view returns (
        uint256,
        uint256,
        address[] memory,
        uint256[] memory,
        address[][] memory,
        uint256[][] memory
    ) {
        unchecked {
            PotData storage potData = pots[_potId];
            uint256 totalReward = 0;

            uint256 topAlphaCount = potData.topAlphaCount;
            address[] memory rewardedAlphas = new address[](topAlphaCount);
            uint256[] memory alphaRewards = new uint256[](topAlphaCount);
            address[][] memory alphaPlayers = new address[][](topAlphaCount);
            uint256[][] memory alphaPlayerRewards = new uint256[][](topAlphaCount);

            address pivotAlpha = potData.topAlphasHead;
            mapping(address => address) storage topAlphas = potData.topAlphas;
            mapping(address => AlphaData) storage alphas = potData.alphas;
            uint256[] memory rewardPortions = rewardConfigs[potData.rewardConfigId];
            uint256 j = topAlphaCount;
            uint256 temp = potData.value / PORTION_BASE;
            uint256 dust;
            for (uint256 i = 0; i < topAlphaCount; ++i) {
                --j;
                rewardedAlphas[i] = pivotAlpha;
                uint256 reward = temp * rewardPortions[j];
                alphaRewards[i] = reward;
                (alphaPlayers[i], alphaPlayerRewards[i], dust) = getAlphaRewards(alphas[pivotAlpha], reward);
                totalReward += reward - dust;
                pivotAlpha = topAlphas[pivotAlpha];
            }

            return (
                totalReward,
                potData.value - totalReward,
                rewardedAlphas,
                alphaRewards,
                alphaPlayers,
                alphaPlayerRewards
            );
        }
    }

    function getLatestPotGame() public view returns (address) {
        return pots[potNumber].game;
    }

    function getLatestPotInfo() public view returns (
        uint64, uint256, uint256, uint256,
        address, uint40, uint40,
        bool, uint8, uint8, uint8,
        uint16, uint32, uint32
    ) {
        uint64 potId = potNumber;
        PotData storage potData = pots[potId];
        return (
            potId,
            potData.value,
            potData.ticketPrice,
            potData.qualificationThreshold,
            potData.game,
            potData.endAt,
            potData.additionalDuration,
            potData.isOpening,
            potData.feePercentage,
            potData.operationFundingPercentage,
            potData.reservePercentage,
            potData.rewardConfigId,
            potData.submissionCount,
            potData.topAlphaCount
        );
    }

    function isLatestPotEnded() public view returns (bool) {
        return pots[potNumber].endAt < block.timestamp;
    }

    function isPlayerQualified(uint64 _potId, address _player, address _alpha) external view returns (bool) {
        return _player == _alpha
            || (IAlphaKeysFactory(alphaFactory).getKeysPlayer(_alpha) != ADDRESS_ZERO
                && IERC20Upgradeable(_alpha).balanceOf(_player) >= pots[_potId].qualificationThreshold);
    }

    function hasTicket(address _player) external view returns (bool) {
        return players[_player].ticket == potNumber;
    }

    function registerGame(
        address _gameAddress,
        string calldata _name,
        uint256 _defaultTicketPrice,
        uint40 _additionalDuration,
        uint8 _feePercentage
    ) external onlyOwner {
        if (registeredGames.hasValue(_gameAddress)) revert GameAlreadyRegistered();
        if (_defaultTicketPrice == 0 || _additionalDuration == 0 || _feePercentage > 100) revert InvalidParams();
        registeredGames.insert(_gameAddress);

        GameData storage gameData = games[_gameAddress];

        gameData.name = _name;
        gameData.defaultTicketPrice = _defaultTicketPrice;
        gameData.additionalDuration = _additionalDuration;
        gameData.feePercentage = _feePercentage;

        emit GameRegistration(
            _gameAddress,
            _name,
            _defaultTicketPrice,
            _feePercentage,
            _additionalDuration
        );
    }

    function removeGame(address _gameAddress) external onlyOwner onlyRegisteredGame(_gameAddress) {
        registeredGames.erase(_gameAddress);
        emit GameRemoval(_gameAddress);
    }

    function compare(address _alpha1, address _alpha2) external view returns (bool) {
        uint64 potId = potNumber;
        AlphaData storage alphaData1 = pots[potId].alphas[_alpha1];
        AlphaData storage alphaData2 = pots[potId].alphas[_alpha2];
        int256 totalScore1 = alphaData1.totalScore;
        int256 totalScore2 = alphaData2.totalScore;
        if (totalScore1 > totalScore2) return true;
        if (totalScore1 == totalScore2) {
            return alphaData1.lastSubmission < alphaData2.lastSubmission;
        }
        return false;
    }

    function createPot(
        address _gameAddress,
        uint256 _ticketPrice,
        uint40 _initialDuration,
        uint256 _initialValue,
        uint256 _qualificationThreshold,
        uint16 _rewardConfigId
    ) internal {
        if (_initialDuration == 0
            || _qualificationThreshold == 0
            || _rewardConfigId > rewardConfigNumber) revert InvalidParams();

        GameData storage gameData = games[_gameAddress];

        uint8 feePercentage = gameData.feePercentage;
        if (feePercentage + operationFundingPercentage + reservePercentage > 100) {
            revert ConflictPercentages(_gameAddress);
        }

        unchecked {
            uint64 potId = ++potNumber;
            uint256 value = _initialValue + reservePot;
            uint256 ticketPrice = _ticketPrice > 0 ? _ticketPrice : gameData.defaultTicketPrice;
            _rewardConfigId = _rewardConfigId > 0 ? _rewardConfigId : rewardConfigNumber;

            PotData storage potData = pots[potId];

            potData.game = _gameAddress;
            potData.value = value;
            potData.ticketPrice = ticketPrice;
            potData.qualificationThreshold = _qualificationThreshold;
            potData.feePercentage = feePercentage;
            potData.operationFundingPercentage = operationFundingPercentage;
            potData.reservePercentage = reservePercentage;
            potData.additionalDuration = games[_gameAddress].additionalDuration;
            potData.rewardConfigId = _rewardConfigId;
            potData.isOpening = true;
            potData.endAt = uint40(block.timestamp + _initialDuration);

            potSecondaryAlphas[potId].comparator = address(this);

            games[_gameAddress].pots.push(potId);
            reservePot = 0;

            IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), _initialValue);

            emit PotCreation(
                potId,
                _gameAddress,
                ticketPrice,
                _initialDuration,
                value,
                _qualificationThreshold,
                _rewardConfigId
            );
        }
    }

    function createPotOfRandomGame(
        uint256 _ticketPrice,
        uint40 _initialDuration,
        uint256 _initialValue,
        uint256 _qualificationThreshold,
        uint16 _rewardConfigId
    ) external nonReentrant onlyOwner whenNoPotIsOpening whenNotPaused {
        unchecked {
            if (registeredGames.size() == 0) revert NoRegisteredGame();
            address gameAddress = registeredGames.values[
                uint256(keccak256(abi.encodePacked(
                    block.number,
                    block.timestamp,
                    blockhash(block.number),
                    potNumber
                ))) % registeredGames.size()
            ];

            createPot(
                gameAddress,
                _ticketPrice,
                _initialDuration,
                _initialValue,
                _qualificationThreshold,
                _rewardConfigId
            );
        }
    }

    function createPotOfSpecificGame(
        address _gameAddress,
        uint256 _ticketPrice,
        uint40 _initialDuration,
        uint256 _initialValue,
        uint256 _qualificationThreshold,
        uint16 _rewardConfigId
    ) external nonReentrant onlyOwner whenNoPotIsOpening whenNotPaused onlyRegisteredGame(_gameAddress) {
        createPot(
            _gameAddress,
            _ticketPrice,
            _initialDuration,
            _initialValue,
            _qualificationThreshold,
            _rewardConfigId
        );
    }

    function raisePot(uint256 _value)
    external nonReentrant whenNotPaused {
        uint64 potId = potNumber;
        unchecked {
            if (pots[potId].isOpening) {
                pots[potId].value += _value;
            } else {
                reservePot += _value;
            }
        }
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), _value);
        emit PotRaise(potId, msg.sender, _value);
    }

    function buyTicket(address _player, bytes calldata _signature)
    external nonReentrant whenNotPaused whenPotIsOpening {
        uint64 potId = potNumber;
        PotData storage potData = pots[potId];
        if (potData.endAt < block.timestamp) revert PotEnded();

        PlayerData storage playerData = players[_player];
        if (playerData.ticket == potId) revert AlreadyHavingATicket();
        playerData.ticket = potId;

        if (!Signature.verifyEthSignature(
            _player,
            keccak256(abi.encodePacked(
                address(this),
                _player,
                playerData.nonce
            )),
            _signature
        )) {
            revert InvalidSignature();
        }

        unchecked {
            ++playerData.nonce;
        }

        uint256 ticketPrice = potData.ticketPrice;
        if (ticketPrice != 0) {
            uint256 value = ticketPrice;
            uint256 temp = value / 100;
            uint256 fee = temp * potData.feePercentage;
            uint256 funding = temp * potData.operationFundingPercentage;
            uint256 reserve = temp * potData.reservePercentage;
            value -= fee;
            value -= funding;
            value -= reserve;

            unchecked {
                potData.value += value;
                reservePot += reserve;
            }

            IERC20Upgradeable tokenContract = IERC20Upgradeable(token);
            tokenContract.safeTransferFrom(_player, address(this), potData.ticketPrice);
            tokenContract.safeTransfer(treasury, fee);
            tokenContract.safeTransfer(operationFund, funding);
        }

        emit TicketBuy(potId, _player);
    }

    function submitScore(
        address _player,
        address _alpha,
        int256 _score
    ) external nonReentrant whenNotPaused whenPotIsOpening {
        uint64 potId = potNumber;
        PlayerData storage playerData = players[_player];
        if (playerData.ticket != potId) revert NoTicket();
        playerData.ticket = 0;

        PotData storage potData = pots[potId];
        if (potData.game != msg.sender) revert Unauthorized();
        if (potData.endAt < block.timestamp) revert PotEnded();

        if (_player != _alpha
            && (IAlphaKeysFactory(alphaFactory).getKeysPlayer(_alpha) == ADDRESS_ZERO
                || IERC20Upgradeable(_alpha).balanceOf(_player) < potData.qualificationThreshold)) {
            revert InvalidAlpha();
        }

        mapping(address => AlphaData) storage alphas = potData.alphas;
        AlphaData storage alphaData = alphas[_alpha];
        if (!alphaData.players.hasValue(_player)) alphaData.players.insert(_player);
        unchecked {
            ++alphaData.playerSubmissions[_player];
            ++alphaData.totalSubmission;
        }

        int256 score = alphaData.totalScore;
        score += _score;
        alphaData.totalScore = score;
        unchecked {
            alphaData.lastSubmission = ++potData.submissionCount;

            Tier tier = alphaData.tier;

            if (tier == Tier.TOP_TIER) {
                mapping(address => address) storage topAlphas = potData.topAlphas;
                address pivotAlpha = potData.topAlphasHead;

                if (_score <= 0) { // DOWN RANK
                    Heap.AddressHeap storage secondaryAlphas = potSecondaryAlphas[potId];
                    bool outTop;
                    address topSecondaryAlpha;

                    // Check if the top secondary alpha can rise into top alphas
                    if (secondaryAlphas.size > 0) {
                        topSecondaryAlpha = secondaryAlphas.peek();
                        if (score <= alphas[topSecondaryAlpha].totalScore) {
                            outTop = true;
                            secondaryAlphas.pop();
                        }
                    }

                    // Remove the alpha from linked list
                    if (pivotAlpha == _alpha) {
                        potData.topAlphasHead = topAlphas[pivotAlpha];
                    } else {
                        while (true) {
                            address nextAlpha = topAlphas[pivotAlpha];
                            if (nextAlpha == _alpha) {
                                topAlphas[pivotAlpha] = topAlphas[nextAlpha];
                                break;
                            }
                            pivotAlpha = nextAlpha;
                        }
                    }

                    if (outTop) {
                        // Push the alpha to the heap
                        secondaryAlphas.push(_alpha);
                        alphaData.tier = Tier.SECONDARY_TIER;

                        // Insert the top secondary alpha into linked list
                        topAlphas[topSecondaryAlpha] = potData.topAlphasHead;
                        potData.topAlphasHead = topSecondaryAlpha;
                        alphas[topSecondaryAlpha].tier = Tier.TOP_TIER;
                    } else {
                        // Insert the alpha into linked list again
                        pivotAlpha = potData.topAlphasHead;
                        if (pivotAlpha == ADDRESS_ZERO || score <= alphas[pivotAlpha].totalScore) {
                            topAlphas[_alpha] = pivotAlpha;
                            potData.topAlphasHead = _alpha;
                        } else {
                            while (true) {
                                address nextAlpha = topAlphas[pivotAlpha];
                                if (nextAlpha == ADDRESS_ZERO || score <= alphas[nextAlpha].totalScore) {
                                    topAlphas[pivotAlpha] = _alpha;
                                    topAlphas[_alpha] = nextAlpha;
                                    break;
                                }
                                pivotAlpha = nextAlpha;
                            }
                        }
                    }
                } else { // UP RANK
                    if (pivotAlpha == _alpha) {
                        // Remove the alpha when being head of the linked list
                        address nextAlpha = topAlphas[pivotAlpha];
                        potData.topAlphasHead = nextAlpha;
                        pivotAlpha = nextAlpha;
                    }

                    if (pivotAlpha == ADDRESS_ZERO || score <= alphas[pivotAlpha].totalScore) {
                        // Set the alpha address as head of the linked list
                        topAlphas[_alpha] = pivotAlpha;
                        potData.topAlphasHead = _alpha;
                    } else {
                        while (true) {
                            address nextAlpha = topAlphas[pivotAlpha];
                            if (nextAlpha == _alpha) {
                                // Remove the alpha from the linked list to look for its new position
                                nextAlpha = topAlphas[nextAlpha];
                                topAlphas[pivotAlpha] = nextAlpha;
                            }

                            if (nextAlpha == ADDRESS_ZERO || score <= alphas[nextAlpha].totalScore) {
                                // Insert the alpha into the linked list
                                topAlphas[pivotAlpha] = _alpha;
                                topAlphas[_alpha] = nextAlpha;
                                pivotAlpha = nextAlpha;
                                break;
                            }

                            pivotAlpha = nextAlpha;
                        }
                    }

                    if (potData.topAlphaCount > rewardConfigs[potData.rewardConfigId].length) {
                        // When reward limit exceeded, drop the head of the linked list onto the heap
                        pivotAlpha = potData.topAlphasHead;
                        potSecondaryAlphas[potId].push(pivotAlpha);
                        alphas[pivotAlpha].tier = Tier.SECONDARY_TIER;
                        potData.topAlphasHead = topAlphas[potData.topAlphasHead];
                    }

                    if (pivotAlpha == ADDRESS_ZERO) {
                        // Increase duration when there is a alpha actively becomes the best alpha.
                        uint256 extendedTimestamp = block.timestamp + potData.additionalDuration;
                        if (potData.endAt < extendedTimestamp) {
                            potData.endAt = uint40(extendedTimestamp);
                        }
                    }
                }
            } else if (tier == Tier.SECONDARY_TIER) {
                Heap.AddressHeap storage secondaryAlphas = potSecondaryAlphas[potId];
                if (_score <= 0) { // DOWN RANK
                    // Update data for the alpha in heap
                    secondaryAlphas.down(_alpha);
                } else { // UP RANK
                    mapping(address => address) storage topAlphas = potData.topAlphas;
                    address pivotAlpha = potData.topAlphasHead;
                    if (score > alphas[pivotAlpha].totalScore) {
                        secondaryAlphas.remove(_alpha);
                        // Drop the head of the linked list onto the heap
                        secondaryAlphas.push(pivotAlpha);
                        alphas[pivotAlpha].tier = Tier.SECONDARY_TIER;
                        pivotAlpha = topAlphas[pivotAlpha];
                        potData.topAlphasHead = pivotAlpha;

                        if (pivotAlpha == ADDRESS_ZERO || score <= alphas[pivotAlpha].totalScore) {
                            // Set the alpha address as head of the linked list
                            topAlphas[_alpha] = pivotAlpha;
                            potData.topAlphasHead = _alpha;
                        } else {
                            while (true) {
                                address nextAlpha = topAlphas[pivotAlpha];

                                if (nextAlpha == ADDRESS_ZERO || score <= alphas[nextAlpha].totalScore) {
                                    // Insert the alpha into linked list
                                    topAlphas[pivotAlpha] = _alpha;
                                    topAlphas[_alpha] = nextAlpha;
                                    pivotAlpha = nextAlpha;
                                    break;
                                }

                                pivotAlpha = nextAlpha;
                            }
                        }

                        if (pivotAlpha == ADDRESS_ZERO) {
                            // Increase duration when there is a alpha actively becomes the best alpha.
                            uint256 extendedTimestamp = block.timestamp + potData.additionalDuration;
                            if (potData.endAt < extendedTimestamp) {
                                potData.endAt = uint40(extendedTimestamp);
                            }
                        }

                        alphaData.tier = Tier.TOP_TIER;
                    } else {
                        // Update data for the alpha in heap
                        secondaryAlphas.up(_alpha);
                    }
                }
            } else {
                address pivotAlpha = potData.topAlphasHead;
                uint256 rewardLimit = rewardConfigs[potData.rewardConfigId].length;
                uint256 topAlphaCount = potData.topAlphaCount;
                if (topAlphaCount < rewardLimit || score > alphas[pivotAlpha].totalScore) {
                    // New alpha belongs to top alphas
                    mapping(address => address) storage topAlphas = potData.topAlphas;
                    if (pivotAlpha == ADDRESS_ZERO || score <= alphas[pivotAlpha].totalScore) {
                        topAlphas[_alpha] = pivotAlpha;
                        potData.topAlphasHead = _alpha;
                        ++topAlphaCount;
                    } else {
                        while (true) {
                            address nextAlpha = topAlphas[pivotAlpha];

                            if (nextAlpha == ADDRESS_ZERO || score <= alphas[nextAlpha].totalScore) {
                                // Insert the alpha into linked list
                                topAlphas[pivotAlpha] = _alpha;
                                topAlphas[_alpha] = nextAlpha;
                                ++topAlphaCount;
                                pivotAlpha = nextAlpha;
                                break;
                            }

                            pivotAlpha = nextAlpha;
                        }
                    }

                    if (pivotAlpha == ADDRESS_ZERO) {
                        // Increase duration when there is a alpha actively becomes the best player.
                        uint256 extendedTimestamp = block.timestamp + potData.additionalDuration;
                        if (potData.endAt < extendedTimestamp) {
                            potData.endAt = uint40(extendedTimestamp);
                        }
                    }

                    if (topAlphaCount > rewardLimit) {
                        // Drop the head of the linked list onto the heap
                        --topAlphaCount;
                        pivotAlpha = potData.topAlphasHead;
                        potSecondaryAlphas[potId].push(pivotAlpha);
                        alphas[pivotAlpha].tier = Tier.SECONDARY_TIER;
                        potData.topAlphasHead = topAlphas[potData.topAlphasHead];
                    }

                    potData.topAlphaCount = uint16(topAlphaCount);
                    alphaData.tier = Tier.TOP_TIER;
                } else {
                    // The new alpha belongs to secondary alphas
                    potSecondaryAlphas[potId].push(_alpha);
                    alphaData.tier = Tier.SECONDARY_TIER;
                }
            }
        }

        emit ScoreSubmission(potId, _player, _alpha, _score);
    }

    function closePot()
    external nonReentrant whenNotPaused whenPotIsOpening {
        unchecked {
            uint64 potId = potNumber;
            if (pots[potId].endAt >= block.timestamp) revert PotNotEnded();
            if (!pots[potId].isOpening) revert PotAlreadyClosed();
            pots[potId].isOpening = false;

            (
                uint256 totalReward,
                uint256 remainValue,
                address[] memory rewardedAlphas,
                ,
                address[][] memory alphaPlayers,
                uint256[][] memory alphaPlayerRewards
            ) = getPotDistributions(potId);

            reservePot += remainValue;
            IERC20Upgradeable tokenContract = IERC20Upgradeable(token);
            uint256 rewardedAlphaNumber = rewardedAlphas.length;
            for (uint256 i = 0; i < rewardedAlphaNumber; ++i) {
                address[] memory currentAlphaPlayers = alphaPlayers[i];
                uint256[] memory currentAlphaRewards = alphaPlayerRewards[i];
                uint256 alphaPlayerNumber = currentAlphaPlayers.length;
                for (uint256 j = 0; j < alphaPlayerNumber; ++j) {
                    uint256 reward = currentAlphaRewards[j];
                    tokenContract.safeTransfer(currentAlphaPlayers[j], reward);
                }
            }

            emit PotClosure(potId, totalReward, remainValue, rewardedAlphaNumber);
        }
    }

    function forceClosePot()
    external nonReentrant onlyOwner whenNotPaused whenPotIsOpening {
        unchecked {
            uint64 potId = potNumber;
            if (!pots[potId].isOpening) revert PotAlreadyClosed();
            pots[potId].isOpening = false;

            (
                uint256 totalReward,
                uint256 remainValue,
                address[] memory rewardedAlphas,
                ,
                address[][] memory alphaPlayers,
                uint256[][] memory alphaPlayerRewards
            ) = getPotDistributions(potId);

            reservePot += remainValue;
            IERC20Upgradeable tokenContract = IERC20Upgradeable(token);
            uint256 rewardedAlphaNumber = rewardedAlphas.length;
            for (uint256 i = 0; i < rewardedAlphaNumber; ++i) {
                address[] memory currentAlphaPlayers = alphaPlayers[i];
                uint256[] memory currentAlphaRewards = alphaPlayerRewards[i];
                uint256 alphaPlayerNumber = currentAlphaPlayers.length;
                for (uint256 j = 0; j < alphaPlayerNumber; ++j) {
                    uint256 reward = currentAlphaRewards[j];
                    tokenContract.safeTransfer(currentAlphaPlayers[j], reward);
                }
            }

            emit PotClosure(potId, totalReward, remainValue, rewardedAlphaNumber);
        }
    }
}
