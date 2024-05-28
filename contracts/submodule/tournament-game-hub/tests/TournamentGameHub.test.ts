import {ethers, upgrades} from "hardhat";
import {expect} from "chai";
import Random from "random-seed";
import {
    TournamentGameHub,
    TournamentGameHub__factory,
    TestAlphaKeysFactory,
    TestAlphaKeysFactory__factory,
    TestToken,
    TestToken__factory,
    GameLibrary,
    GameLibrary__factory,
} from "../typechain-types";
import {BigNumber, Wallet} from "ethers";
import {GasCalculator, RandomUtils, isEqualArray, isEqualBigNumberArray, callTransaction, verifyContractData, signMessage} from "./helper";
import {Game, CreatePotParams, CreatePotWithSignatureParams} from "./paramsHelper";

let GameLib: GameLibrary__factory, gameLib: GameLibrary;
let GameHub: TournamentGameHub__factory, gameHub: TournamentGameHub;
let AlphaKeysFactory: TestAlphaKeysFactory__factory, alphaFactory: TestAlphaKeysFactory;
let Token: TestToken__factory, token: TestToken;

let owner: any, treasury: any, operationFund: any, games: Game[];
let alphas: TestToken[], players: any[][];
let defaultBalanceRequirement: number, rewardConfigs: number[][];
let rng: Random.RandomSeed, randUtils: RandomUtils;
let gasCalculator: GasCalculator;
let defaultCreatePotParams: CreatePotParams;

let default_games = 2;
let default_alphas = 1;
let default_players_per_alpha = 3;

async function getSignature(potId: BigNumber, user: Wallet) {
    const nonce = await gameHub.nonces(user.address);
    return await signMessage(
        user,
        ["address", "uint64", "address", "uint256"],
        [gameHub.address, potId, user.address, nonce],
    );
}

describe('5. TournamentGameHub', async () => {
    before(async () => {
        GameLib = await ethers.getContractFactory('GameLibrary');
        AlphaKeysFactory = await ethers.getContractFactory('TestAlphaKeysFactory');
        Token = await ethers.getContractFactory('TestToken');
        GameHub = await ethers.getContractFactory('TournamentGameHub');

        gasCalculator = new GasCalculator();

        const seed = Date.now().toString();
        console.log(`Seed: ${seed}`);
        rng = Random.create(seed);
        randUtils = new RandomUtils(rng);
    });

    async function setupGames(n_games: number) {
        games = [];
        for(let i = 0; i < n_games; ++i) {
            const wallet = new ethers.Wallet(ethers.utils.id(`Game${i.toString()}`), ethers.provider)
            games.push(new Game({
                wallet: wallet,
                address: wallet.address,
                name: `Mock Game ${i}`,
                defaultTicketPrice: ethers.utils.parseEther("1"),
                defaultAdditionalDuration: 900,
                defaultFeePercentage: 10,
            }));
            await treasury.sendTransaction({
                to: wallet.address,
                value: ethers.utils.parseEther('20')
            });
            await callTransaction(
                gameLib.connect(owner).registerGame(...games[i].toArray())
            );
        }
    }

    async function setupAlphasAndPlayers(n_alphas: number, n_players_per_alpha: number) {
        alphas = [];
        players = [];
        for (let i = 0; i < n_alphas; ++i) {
            const alpha = await upgrades.deployProxy(Token, [`Alpha${i}`, `A${i}`]) as TestToken;
            await alpha.deployed();

            const alpha_players = [];
            for(let j = 0; j < n_players_per_alpha; ++j) {
                alpha_players.push(new ethers.Wallet(
                    ethers.utils.id(`Alpha${i.toString()}_Player${j.toString()}`),
                    ethers.provider
                ));
                await treasury.sendTransaction({
                    to: alpha_players[j].address,
                    value: ethers.utils.parseEther('20')
                });
                await callTransaction(token.connect(alpha_players[j]).approve(
                    gameHub.address,
                    ethers.utils.parseEther("100"),
                ));
                if (j == 0) {
                    await callTransaction(
                        alphaFactory.connect(alpha_players[j]).registerKeys(alpha.address)
                    );
                }
            }
            await callTransaction(token.mintFor(
                alpha_players.map(p => p.address),
                ethers.utils.parseEther("100"),
            ));
            await callTransaction(alpha.mintFor(
                alpha_players.map(p => p.address),
                ethers.utils.parseEther("100"),
            ));

            players.push(alpha_players);
            alphas.push(alpha);
        }
    }

    beforeEach(async () => {
        const accounts = await ethers.getSigners();
        owner = accounts[0];
        treasury = accounts[1];
        operationFund = accounts[2];

        gameLib = await upgrades.deployProxy(GameLib) as GameLibrary;
        token = await upgrades.deployProxy(Token, ['Name', 'SYMBOL']) as TestToken;
        alphaFactory = await upgrades.deployProxy(AlphaKeysFactory) as TestAlphaKeysFactory;
        await gameLib.deployed();
        await alphaFactory.deployed();
        await token.deployed();

        // Init games
        await setupGames(default_games);

        // Init TournamentGameHub contract
        defaultBalanceRequirement = 1;

        rewardConfigs = [
            // padding zero position
            [],
            // config 1: actual production config
            [
                8000,   // 80%
                800,    // 8%
                100,    // 1%
                100,    // 1%
                100,    // 1%
                100,    // 1%
                100,    // 1%
                100,    // 1%
                100,    // 1%
                100,    // 1%
                50,     // 0.5%
                50,     // 0.5%
                50,     // 0.5%
                50,     // 0.5%
                50,     // 0.5%
                50,     // 0.5%
                25,     // 0.25%
                25,     // 0.25%
                25,     // 0.25%
                25,     // 0.25%
            ],
            // config 2: smaller case for debugging
            [8000, 1000, 500, 500],
            // config 3: edge case
            [10000],
        ];

        gameHub = await upgrades.deployProxy(
            GameHub,
            [
                token.address,
                treasury.address,
                gameLib.address,
                alphaFactory.address,
                defaultBalanceRequirement,
                rewardConfigs[1],
            ],
        ) as TournamentGameHub;
        await gameHub.deployed();

        for(let i = 2; i < rewardConfigs.length; ++i) {
            await callTransaction(gameHub.addNewRewardConfig(rewardConfigs[i]));
        }

        // Init alphas and players
        await setupAlphasAndPlayers(default_alphas, default_players_per_alpha);

        gasCalculator.reset();

        createDefaultParams();
    });

    function createDefaultParams() {
        defaultCreatePotParams = new CreatePotParams({
            alpha: alphas[0].address,
            gameAddress: games[0].address,
            ticketPrice: ethers.utils.parseEther("1"),
            feePercentage: 10,
            initialDuration: 3600,
            additionalDuration: 900,
            initialValue: ethers.utils.parseEther("10"),
            balanceRequirement: ethers.utils.parseEther("2"),
            rewardConfigId: 2,
        });
    }

    describe('5.1. initialize', async() => {
        it('5.1.1. correct owner after initialize', async() => {
            expect(await gameHub.owner()).to.equal(owner.address, "Incorrect owner after initialize");
            expect(await gameHub.paused()).to.equal(false, "Incorrect pause state after initialize");
            expect(await gameHub.token()).to.equal(token.address, "Incorrect token after initialize");
            expect(await gameHub.treasury()).to.equal(treasury.address, "Incorrect treasury after initialize");
            expect(await gameHub.gameLibrary()).to.equal(gameLib.address, "Incorrect gameLibrary after initialize");
            expect(await gameHub.alphaKeysFactory()).to.equal(alphaFactory.address, "Incorrect alphaFactory after initialize");
            expect(await gameHub.defaultBalanceRequirement()).to.equal(defaultBalanceRequirement, "Incorrect token after initialize");
            expect(await gameHub.potNumber()).to.equal(0, "Incorrect potNumber after initialize");

            for(let i = 1; i < rewardConfigs.length; ++i) {
                for(let j = 0; j < rewardConfigs[i].length; ++j) {
                    expect(await gameHub.rewardConfigs(i, j)).to.equal(rewardConfigs[i][j], `Incorrect player ${j} reward of config ${i}`);
                }
            }
        });
    });

    describe('5.2. version', async() => {
        it('5.2.1. correct version', async() => {
            expect(await gameLib.version()).to.equal("v0.0.1", "Incorrect version");
        });
    });

    describe('5.3. pause', async() => {

    });

    describe('5.4. unpause', async() => {

    });

    describe('5.5. updateToken', async() => {

    });

    describe('5.6. updateTreasury', async() => {

    });

    describe('5.7. updateGameLibrary', async() => {

    });

    describe('5.8. updateAlphaKeysFactory', async() => {

    });

    describe('5.9. updateDefaultBalanceRequirement', async() => {

    });

    describe('5.10. addNewRewardConfig', async() => {

    });

    describe('5.11. getGameData', async() => {

    });

    describe('5.12. getPlayerData', async() => {

    });

    describe('5.13. getPotDistributions', async() => {
        async function testGetPotDistributions(n_players: number, rewardConfig: number[]) {
            await setupAlphasAndPlayers(1, n_players + 1);
            await callTransaction(
                gameHub.addNewRewardConfig(rewardConfig)
            );

            const alpha = alphas[0];
            const creator = players[0][0];
            const game = games[0];
            const duration = 3600;
            const ticketPrice = ethers.utils.parseEther("1");
            const alpha_players = players[0].slice(1);

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
                gameAddress: game.address,
                ticketPrice,
                feePercentage: 0,
                rewardConfigId: rewardConfigs.length,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            for(let i = 0; i < n_players; ++i) {
                const signature = await getSignature(potId, alpha_players[i]);
                await callTransaction(
                    gameHub.buyTicket(potId, alpha_players[i].address, signature)
                );
                await callTransaction(
                    gameHub.connect(game.wallet).submitScore(potId, alpha_players[i].address, n_players - i)
                );
            }

            const potData = await gameHub.pots(potId);
            const [totalReward, remainValue, topPlayers, rewards] = await gameHub.getPotDistributions(potId);

            const expectedRewards = rewardConfig.slice(0, alpha_players.length).map(e => potData.value.mul(e).div(10000)).reverse();
            const expectedTotalReward = expectedRewards.reduce((a, b) => a.add(b), ethers.constants.Zero);
            const expectedRemainValue = potData.value.sub(expectedTotalReward);
            const expectedTopPlayers = alpha_players.slice(0, rewardConfig.length).map(p => p.address).reverse();

            expect(totalReward).to.equal(expectedTotalReward, "Incorrect total rewards");
            expect(remainValue).to.equal(expectedRemainValue, "Incorrect remain value");
            expect(isEqualBigNumberArray(expectedRewards, rewards)).to.equal(true, "Incorrect player rewards");
            expect(isEqualArray(expectedTopPlayers, topPlayers)).to.equal(true, "Incorrect top players");
        }

        it('5.13.1. Normal case', async() => {
            await testGetPotDistributions(8, [8000, 1000, 500, 500]);
        });

        it('5.13.2. When player is less than reward configs', async() => {
            await testGetPotDistributions(2, [8000, 1000, 500, 500]);
        });

        it('5.13.3. When there is no player', async() => {
            await testGetPotDistributions(0, [8000, 1000, 500, 500]);
        });

        it('5.13.4. When there is single winner', async() => {
            await testGetPotDistributions(5, [10000]);
        });

        it('5.13.5. When sum of reward config is not 100%', async() => {
            await testGetPotDistributions(5, [4000, 3000, 2000]);
        });
    });

    describe('5.14. getLatestPotIdOfAlpha', async() => {

    });

    describe('5.15. getLatestPotGameOfAlpha', async() => {

    });

    describe('5.16. getLatestPotInfoOfAlpha', async() => {
        it('5.16.1. Correctly get pot info', async () => {
            const alpha = alphas[0];
            const creator = players[0][1];
            const user = players[0][2];
            const game = games[0];
            const initialValue = ethers.utils.parseEther("10");

            const blockNum = (await ethers.provider.getBlock("latest")).timestamp + 1;

            const params = Object.assign(defaultCreatePotParams, {
                alpha: alpha.address,
                gameAddress: game.address,
                initialValue: initialValue,
            });

            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const [
                potId,
                value,
                ticketPrice,
                balanceRequirement,
                alphaAddress,
                gameAddress,
                submissionCount,
                endAt,
                additionalDuration,
                rewardConfigId,
                topPlayerCount,
                feePercentage, 
                isOpening
            ] = await gameHub.getLatestPotInfoOfAlpha(alpha.address);
            expect(potId).to.equal(1, "Incorrect potId");
            expect(value).to.equal(initialValue, "Incorrect value");
            expect(ticketPrice).to.equal(params.ticketPrice, "Incorrect ticketPrice");
            expect(balanceRequirement).to.equal(params.balanceRequirement, "Incorrect balanceRequirement");
            expect(alphaAddress).to.equal(alpha.address, "Incorrect alpha");
            expect(gameAddress).to.equal(game.address, "Incorrect gameAddress");
            expect(submissionCount).to.equal(0, "Incorrect submissionCount");
            expect(endAt).to.equal(blockNum + params.initialDuration, "Incorrect endAt");
            expect(additionalDuration).to.equal(params.additionalDuration, "Incorrect additionalDuration");
            expect(rewardConfigId).to.equal(params.rewardConfigId, "Incorrect rewardConfigId");
            expect(topPlayerCount).to.equal(0, "Incorrect topPlayerCount");
            expect(feePercentage).to.equal(params.feePercentage, "Incorrect feePercentage");
            expect(isOpening).to.equal(true, "Incorrect isOpening");

            await ethers.provider.send('evm_increaseTime', [50 * 60]);
            const signature = await getSignature(potId, user);
            await callTransaction(
                gameHub.buyTicket(potId, user.address, signature)
            );
            await gasCalculator.callTransaction(
                gameHub.connect(game.wallet).submitScore(potId, user.address, 123)
            );

            let potInfo = await gameHub.getLatestPotInfoOfAlpha(alpha.address);
            expect(potInfo[1]).to.equal(value.add(ticketPrice.mul(100 - feePercentage).div(100)), "Incorrect changed value");
            expect(potInfo[6]).to.equal(1, "Incorrect changed submissionCount");
            expect(potInfo[7]).to.equal(endAt + 5 * 60 + 1, "Incorrect changed endAt");
            expect(potInfo[10]).to.equal(1, "Incorrect changed topPlayerCount");

            await ethers.provider.send('evm_increaseTime', [30 * 60]);
            await callTransaction(gameHub.connect(creator).closePot(potId));

            potInfo = await gameHub.getLatestPotInfoOfAlpha(alpha.address);
            expect(potInfo[12]).to.equal(false, "Incorrect changed isOpening");
        });
    });

    describe('5.17. isLatestPotOfAlphaEnded', async() => {

    });

    describe('5.18. isLatestPotOfAlphaCloseable', async() => {

    });

    describe('5.19. isPlayerQualified', async() => {

    });

    describe('5.20. compare', async() => {

    });

    describe('5.21. createPot(address,address,uint256,uint8,uint40,uint40,uint256,uint256,uint32)', async() => {
        it('5.21.1. Correctly create pot', async () => {
            const alpha = alphas[0];
            const creator = players[0][1];
            const game = games[0];
            const initialValue = ethers.utils.parseEther("10");

            const initialCreatorBalance = (await token.balanceOf(creator.address));
            const initialGamehubBalance = (await token.balanceOf(gameHub.address));

            const blockNum = (await ethers.provider.getBlock("latest")).timestamp + 1;

            const params = Object.assign(defaultCreatePotParams, {
                alpha: alpha.address,
                gameAddress: game.address,
                initialValue: initialValue,
            });

            const receipt = await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
            // console.log("Gas consumed:", receipt.gasUsed);

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            expect(potId).to.equal(1, "First pot id should be 1");

            const potData = await gameHub.pots(potId);
            const expectedPotData = {
                alpha: alpha.address,
                endAt: blockNum + params.initialDuration,
                additionalDuration: params.additionalDuration,
                topPlayerCount: 0,
                gameAddress: game.address,
                submissionCount: 0,
                rewardConfigId: params.rewardConfigId,
                feePercentage: params.feePercentage,
                isOpening: true,
                value: initialValue,
                ticketPrice: params.ticketPrice,
                balanceRequirement: params.balanceRequirement,
                topPlayersHead: ethers.constants.AddressZero,
                creator: creator.address,
            }
            verifyContractData(potData, expectedPotData, "potData");

            const filter = gameHub.filters.PotCreation();
            const events = await gameHub.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 PotCreation events");

            const expectedEventData = {
                potId,
                creator: creator.address,
                alpha: alpha.address,
                gameAddress: game.address,
                ticketPrice: ethers.utils.parseEther("1"),
                feePercentage: 10,
                initialDuration: 3600,
                intitialValue: initialValue,
                balanceRequirement: ethers.utils.parseEther("2"),
                rewardConfigId: 2,
            }
            verifyContractData(events[0].args, expectedEventData, "PotCreation event");

            const currentCreatorBalance = (await token.balanceOf(creator.address));
            const currentGamehubBalance = (await token.balanceOf(gameHub.address));
            expect(currentCreatorBalance).to.equal(initialCreatorBalance.sub(initialValue), "Incorrect creator balance after create pot");
            expect(currentGamehubBalance).to.equal(initialGamehubBalance.add(initialValue), "Incorrect creator balance after create pot");
        });

        it('5.21.2. Default params', async () => {
            const alpha = alphas[0];
            const creator = players[0][1];
            const game = games[0];

            const params = Object.assign(defaultCreatePotParams, {
                ticketPrice: 0,
                feePercentage: 0,
                additionalDuration: 0,
                balanceRequirement: 0,
            });

            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const defaultBalanceRequirement = await gameHub.defaultBalanceRequirement();

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const potData = await gameHub.pots(potId);
            expect(potData.ticketPrice).to.equal(game.defaultTicketPrice, "Incorrect default ticketPrice");
            expect(potData.feePercentage).to.equal(game.defaultFeePercentage, "Incorrect default feePercentage");
            expect(potData.additionalDuration).to.equal(game.defaultAdditionalDuration, "Incorrect default additionalDuration");
            expect(potData.balanceRequirement).to.equal(defaultBalanceRequirement, "Incorrect default balanceRequirement");
            expect(games.map(g => g.address).includes(potData.gameAddress), "Returned game address not in registered games")
        });

        it('5.21.3. Fail with InvalidAlpha()', async () => {
            const mockAlpha = await upgrades.deployProxy(Token, ['Name', 'SYMBOL']) as TestToken;
            await mockAlpha.deployed();

            const mockCreator = new ethers.Wallet(ethers.utils.id(`Mock_Creator`), ethers.provider);
            const mockUser = new ethers.Wallet(ethers.utils.id(`Mock_User`), ethers.provider);
            await treasury.sendTransaction({ to: mockCreator.address, value: ethers.utils.parseEther('20') });
            await treasury.sendTransaction({ to: mockUser.address, value: ethers.utils.parseEther('20') });

            const game = games[0];

            const params = Object.assign(defaultCreatePotParams, {
                alpha: mockAlpha.address,
                gameAddress: game.address,
            });

            // Alpha not exist
            await expect(gameHub.connect(mockCreator).createPot(...params.toArray()))
                .to.be.revertedWithCustomError(gameHub, `InvalidAlpha`);

            await callTransaction(
                alphaFactory.connect(mockCreator).registerKeys(mockAlpha.address)
            );

            // User don't have any key of alpha
            await expect(gameHub.connect(mockUser).createPot(...params.toArray()))
                .to.be.revertedWithCustomError(gameHub, `InvalidAlpha`);

            // Creator that don't have any key of alpha still can create pot
            await callTransaction(token.connect(mockCreator).mintFor(
                [mockCreator.address],
                ethers.utils.parseEther("100"),
            ));
            await callTransaction(token.connect(mockCreator).approve(
                gameHub.address,
                ethers.utils.parseEther("100"),
            ));
            await gameHub.connect(mockCreator).createPot(...params.toArray());
        });

        it('5.21.4. Fail with InvalidParam()', async () => {
            const creator = players[0][0];

            const invalidParams1 = Object.assign(defaultCreatePotParams, {
                initialDuration: 0,
            });
            await expect(gameHub.connect(creator).createPot(...invalidParams1.toArray()))
                .to.be.revertedWithCustomError(gameHub, `InvalidParams`);

            const invalidParams2 = Object.assign(defaultCreatePotParams, {
                _rewardConfigId: 0,
            });
            await expect(gameHub.connect(creator).createPot(...invalidParams2.toArray()))
                .to.be.revertedWithCustomError(gameHub, `InvalidParams`);

            const invalidParams3 = Object.assign(defaultCreatePotParams, {
                _rewardConfigId: rewardConfigs.length + 1,
            });
            await expect(gameHub.connect(creator).createPot(...invalidParams3.toArray()))
                .to.be.revertedWithCustomError(gameHub, `InvalidParams`);
        });

        it('5.21.5. Fail when no games in library', async () => {
            const mockGameLib = await upgrades.deployProxy(GameLib) as GameLibrary;
            await mockGameLib.deployed();
            await callTransaction(
                gameHub.connect(owner).updateGameLibrary(mockGameLib.address)
            );

            const creator = players[0][0];
            const params = Object.assign(defaultCreatePotParams, {
                gameAddress: ethers.constants.AddressZero,
                gameLib
            });
            await expect(gameHub.connect(creator).createPot(...params.toArray()))
                .to.be.revertedWithCustomError(gameLib, `NoRegisteredGame`);
        });

        it('5.21.6. Fail when creator have not enough balance or allowance', async () => {
            const mockAlpha = await upgrades.deployProxy(Token, ['Name', 'SYMBOL']) as TestToken;
            await mockAlpha.deployed();
            const mockCreator =  new ethers.Wallet(ethers.utils.id(`Mock_Player`), ethers.provider);
            const initialValue = ethers.utils.parseEther("10");

            await treasury.sendTransaction({
                to: mockCreator.address,
                value: ethers.utils.parseEther('20')
            });

            await callTransaction(
                alphaFactory.connect(mockCreator).registerKeys(mockAlpha.address)
            );
            await callTransaction(
                mockAlpha.mintFor([mockCreator.address], ethers.utils.parseEther("1"))
            );

            const params = Object.assign(defaultCreatePotParams, {
                alpha: mockAlpha.address,
                initialValue,
            });
            await expect(gameHub.connect(mockCreator).createPot(...params.toArray()))
                .to.be.revertedWith(/ERC20:*/);
        });


        it('5.21.7. Fail when current pot is opening', async () => {
            await setupAlphasAndPlayers(2, 5);

            const alpha1 = alphas[0];
            const creator1 = players[0][1];
            const alpha2 = alphas[1];
            const creator2 = players[1][1];

            const params1 = Object.assign(defaultCreatePotParams, {
                alpha: alpha1.address,
            });
            await callTransaction(
                gameHub.connect(creator1).createPot(...params1.toArray())
            );

            const params2 = Object.assign(defaultCreatePotParams, {
                alpha: alpha2.address,
            });
            await callTransaction(
                gameHub.connect(creator2).createPot(...params2.toArray())
            );

            await expect(gameHub.connect(creator2).createPot(...params2.toArray()))
                .to.be.revertedWithCustomError(gameHub, 'LatestPotOfAlphaIsOpening');
        });
    });

    describe('5.22. createPotWithSignature(address, address, address, uint256, uint8, uint40, uint40, uint256, uint256, uint32, bytes)', async() => {
        it('5.22.1. correctly create pot with signature', async() => {
            const {alpha, gameAddress, ticketPrice, initialDuration, initialValue, balanceRequirement, rewardConfigId} = defaultCreatePotParams;

            const creator = players[0][0];
            const nonce = await gameHub.nonces(creator.address);
            const signature = await signMessage(
                creator,
                ["address", "uint256", "address", "address", "uint256", "uint40", "uint256", "uint256", "uint32"],
                [gameHub.address, nonce, alpha, gameAddress, ticketPrice, initialDuration, initialValue, balanceRequirement, rewardConfigId],
            )

            const params = new CreatePotWithSignatureParams({
                ...defaultCreatePotParams,
                creator: creator.address,
                signature,
            });

            const receipt = await callTransaction(
                gameHub.connect(owner).createPotWithSignature(...params.toArray())
            );
            // console.log("Gas consumed:", receipt.gasUsed);

            expect(await gameHub.nonces(creator.address)).to.equal(nonce.add(1), "Nonce not increased after create pot");
        });

        it('5.22.2. Fail when signer is incorrect', async() => {
            const {alpha, gameAddress, ticketPrice, initialDuration, initialValue, balanceRequirement, rewardConfigId} = defaultCreatePotParams;

            const creator = players[0][0];
            const other_user = players[0][1];
            const nonce = await gameHub.nonces(other_user.address);
            const signature = await signMessage(
                other_user,
                ["address", "uint256", "address", "address", "uint256", "uint40", "uint256", "uint256", "uint32"],
                [gameHub.address, nonce, alpha, gameAddress, ticketPrice, initialDuration, initialValue, balanceRequirement, rewardConfigId],
            )

            const params = new CreatePotWithSignatureParams({
                ...defaultCreatePotParams,
                creator: creator.address,
                signature,
            });
            await expect(gameHub.connect(owner).createPotWithSignature(...params.toArray()))
                .to.be.revertedWithCustomError(gameHub, "InvalidSignature");
        });

        it('5.22.3. Fail when nonce is incorrect', async() => {
            const {alpha, gameAddress, ticketPrice, initialDuration, initialValue, balanceRequirement, rewardConfigId} = defaultCreatePotParams;

            const creator = players[0][0];
            const nonce = 123;
            const signature = await signMessage(
                creator,
                ["address", "uint256", "address", "address", "uint256", "uint40", "uint256", "uint256", "uint32"],
                [gameHub.address, nonce, alpha, gameAddress, ticketPrice, initialDuration, initialValue, balanceRequirement, rewardConfigId],
            )

            const params = new CreatePotWithSignatureParams({
                ...defaultCreatePotParams,
                creator: creator.address,
                signature,
            });
            await expect(gameHub.connect(owner).createPotWithSignature(...params.toArray()))
                .to.be.revertedWithCustomError(gameHub, "InvalidSignature");
        });
    });

    describe('5.23. raisePot', async() => {
        let alpha: TestToken;
        let creator: Wallet;
        let user: Wallet;
        let duration: number;

        beforeEach(async () => {
            alpha = alphas[0];
            creator = players[0][1];
            user = players[0][2];
            duration = 3600;

            const params = Object.assign(defaultCreatePotParams, {
                alpha: alpha.address,
                initialValue: ethers.utils.parseEther("10"),
                initialDuration: duration,
            });

            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
        });

        it('5.21.1. Correctly raise pot', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            expect((await gameHub.pots(potId)).value).to.equal(ethers.utils.parseEther("10"), "Incorrect pot value initially");

            await callTransaction(
                gameHub.connect(user).raisePot(potId, ethers.utils.parseEther("1"))
            );
            expect((await gameHub.pots(potId)).value).to.equal(ethers.utils.parseEther("11"), "Incorrect pot value after first raiser");

            await callTransaction(
                gameHub.connect(creator).raisePot(potId, ethers.utils.parseEther("2"))
            );
            expect((await gameHub.pots(potId)).value).to.equal(ethers.utils.parseEther("13"), "Incorrect pot value after first raiser");


            const filter = gameHub.filters.PotRaise();
            const events = await gameHub.queryFilter(filter);
            expect(events.length).to.equal(2, "There should be 2 PotRaise events");

            const expectedEvent1 = {
                potId,
                raiser: user.address,
                value: ethers.utils.parseEther("1"),
            };
            verifyContractData(events[0].args, expectedEvent1, "PotRaise event 1");

            const expectedEvent2 = {
                potId,
                raiser: creator.address,
                value: ethers.utils.parseEther("2"),
            };
            verifyContractData(events[1].args, expectedEvent2, "PotRaise event 2");
        });

        it('5.21.2. Fail when pot is not opening', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            // const potData = await gameHub.pots(potId);
            await ethers.provider.send('evm_increaseTime', [duration + 1]);
            await callTransaction(gameHub.connect(creator).closePot(potId));

            await expect(gameHub.connect(creator).raisePot(potId, ethers.utils.parseEther("1")))
                .to.be.revertedWithCustomError(gameHub, 'PotEnded');
        });
    });

    describe('5.24. buyTicket', async() => {
        let alpha: TestToken;
        let alphaOwner: Wallet;
        let creator: Wallet;
        let user: Wallet;
        let initialValue: BigNumber;
        let duration: number;

        beforeEach(async () => {
            alpha = alphas[0];
            alphaOwner = players[0][0];
            creator = players[0][1];
            user = players[0][2];
            duration = 3600;
            initialValue = ethers.utils.parseEther("10");

            const params = Object.assign(defaultCreatePotParams, {
                alpha: alpha.address,
                initialValue,
                initialDuration: duration,
            });

            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
        });

        it('5.24.1. Correctly buy ticket', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const expectedEvents = [];

            for (const user of players[0].slice(1)) {
                const signature = await getSignature(potId, user);

                const initialAlphaOnwerBalance = await token.balanceOf(alphaOwner.address);
                const initialUserBalance = await token.balanceOf(user.address);
                const initialGamehubBalance = await token.balanceOf(gameHub.address);
                const initialTreasuryBalance = await token.balanceOf(treasury.address);
                const initialPotValue = (await gameHub.pots(potId)).value;

                const nonce = await gameHub.nonces(user.address);

                await callTransaction(
                    gameHub.connect(user).buyTicket(potId, user.address, signature),
                );

                const playerData = await gameHub.getPlayerData(potId, user.address);
                expect(playerData.hasTicket).to.equal(true, "Should have ticket after buying");

                const potData = await gameHub.pots(potId);

                const value = potData.ticketPrice;
                const fee = value.div(100).mul(potData.feePercentage);
                const alphaFee = value.div(100).mul(potData.alphaFeePercentage);
                const expectedPotValue = initialPotValue.add(value).sub(fee).sub(alphaFee);
                expect(potData.value).to.equal(expectedPotValue, "Value of pot should be raised correctly after buying ticket");

                const expectedAlphaOnwerBalance = initialAlphaOnwerBalance.add(alphaFee);
                const expectedUserBalance = initialUserBalance.sub(value);
                const expectedGamehubBalance = initialGamehubBalance.add(value).sub(fee).sub(alphaFee);
                const expectedTreasuryBalance = initialTreasuryBalance.add(fee);

                expect(await token.balanceOf(user.address)).to.equal(expectedUserBalance, "Incorrect user balance after buy ticket");
                expect(await token.balanceOf(gameHub.address)).to.equal(expectedGamehubBalance, "Incorrect gameHub balance after buy ticket");
                expect(await token.balanceOf(treasury.address)).to.equal(expectedTreasuryBalance, "Incorrect treasury balance after buy ticket");
                expect(await token.balanceOf(alphaOwner.address)).to.equal(expectedAlphaOnwerBalance, "Incorrect alpha owner balance after buy ticket");

                expect(await gameHub.nonces(user.address)).to.equal(nonce.add(1), "Nonce not increased after buy ticket");

                expectedEvents.push({
                    potId,
                    buyer: user.address,
                });
            }

            const filter = gameHub.filters.TicketBuy();
            const events = await gameHub.queryFilter(filter);
            expect(events.length).to.equal(expectedEvents.length, `There should be ${expectedEvents.length} TicketBuy events`);

            for(let i = 0; i < expectedEvents.length; ++i) {
                verifyContractData(events[i].args, expectedEvents[i], `TicketBuy event #${i}`);
            }
        });

        it('5.24.2. Fail when signature is invalid', async () => {
            // Wrong user
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const nonce = await gameHub.nonces(user.address);
            const signature = await signMessage(
                user,
                ["address", "uint64", "address", "uint256"],
                [gameHub.address, potId, user.address, nonce],
            )
            await expect(gameHub.connect(user).buyTicket(potId, creator.address, signature))
                .to.be.revertedWithCustomError(gameHub, 'InvalidSignature');

            // Wrong data
            const signature2 = await signMessage(
                user,
                ["address", "uint64", "address", "uint256"],
                [gameHub.address, potId, user.address, 123],
            )
            await expect(gameHub.connect(user).buyTicket(potId, user.address, signature2))
                .to.be.revertedWithCustomError(gameHub, 'InvalidSignature');
        });

        it('5.24.3. Fail when pot not opening', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await ethers.provider.send('evm_increaseTime', [duration + 1]);
            await callTransaction(gameHub.connect(creator).closePot(potId));

            const signature = await getSignature(potId, user);
            await expect(gameHub.connect(user).buyTicket(potId, user.address, signature))
                .to.be.revertedWithCustomError(gameHub, 'PotEnded');
        });

        it('5.24.4. Fail when user is not pot creator and not enough key', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const sink = new ethers.Wallet(ethers.utils.id("sink"), ethers.provider);
            const alphaOwner = players[0][0];

            // Alpha owner without key can still buy ticket
            const alphaOwnerBalance = await alpha.balanceOf(alphaOwner.address);
            await callTransaction(
                alpha.connect(alphaOwner).transfer(sink.address, alphaOwnerBalance)
            );

            const alphaOwnerSignature = await getSignature(potId, alphaOwner);
            await callTransaction(
                gameHub.connect(alphaOwner).buyTicket(potId, alphaOwner.address, alphaOwnerSignature)
            );

            // User withour alpha key cannot buy ticket
            const userBalance = await alpha.balanceOf(user.address);
            await callTransaction(
                alpha.connect(user).transfer(sink.address, userBalance)
            );

            const userSignature = await getSignature(potId, user);
            await expect(gameHub.connect(user).buyTicket(potId, user.address, userSignature))
                .to.be.revertedWithCustomError(gameHub, 'Unauthorized')
        });

        it('5.24.5. Fail when user already have ticket', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            const userSignature1 = await getSignature(potId, user);
            await callTransaction(
                gameHub.connect(user).buyTicket(potId, user.address, userSignature1)
            );

            const userSignature2 = await getSignature(potId, user);
            await expect(gameHub.connect(user).buyTicket(potId, user.address, userSignature2))
                .to.be.revertedWithCustomError(gameHub, 'AlreadyHavingATicket')
        });


        it('5.24.6. Fail when user not enough token', async () => {
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const sink = new ethers.Wallet(ethers.utils.id("sink"), ethers.provider);

            const userBalance = await alpha.balanceOf(user.address);
            await callTransaction(
                token.connect(user).transfer(sink.address, userBalance)
            );

            const userSignature = await getSignature(potId, user);
            await expect(gameHub.connect(user).buyTicket(potId, user.address, userSignature))
                .to.be.revertedWith(/ERC20:*/);
        });
    });

    describe('5.25. submitScore', async() => {
        it('5.25.1. Correctly submit score', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const user = players[0][1];
            const game = games[0];
            const duration = 3600;
            const params = Object.assign(defaultCreatePotParams, {
                initialDuration: duration,
                gameAddress: game.address,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const signature = await getSignature(potId, user);
            await callTransaction(
                gameHub.buyTicket(potId, user.address, signature)
            );
            await callTransaction(
                gameHub.connect(game.wallet).submitScore(potId, user.address, 123)
            );

            const filter = gameHub.filters.ScoreSubmission();
            const events = await gameHub.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 ScoreSubmission events");

            const playerData = await gameHub.getPlayerData(potId, user.address);
            expect(playerData.hasTicket).to.equal(false, "Ticket should be spent after submit score");
            expect(playerData.usedTickets).to.equal(1, "Used tickets count should be increased after submit score");
            expect(playerData.score).to.equal(123, "Player score should be increased after submit score");
            expect(playerData.lastSubmission).to.equal(1, "Last submission should be increased after submit score");

            const expectedEvent = {
                potId,
                alpha: alpha.address,
                player: user.address,
                score: 123,
            };
            verifyContractData(events[0].args, expectedEvent, "ScoreSubmission event");
        });

        async function testWithConfig(n_accounts: number, n_rewards: number, n_submission: number, value_range: [number, number]) {
            await setupAlphasAndPlayers(1, n_accounts);
            const alpha = alphas[0];
            const creator = players[0][0];
            const game = games[0];
            const ticketPrice = ethers.utils.parseEther('0.00001');

            const rewardPortions = [];
            for (let i = 0; i < n_rewards; ++i) rewardPortions.push(100);
            await callTransaction(gameHub.addNewRewardConfig(rewardPortions));

            const params = Object.assign(defaultCreatePotParams, {
                alpha: alpha.address,
                gameAddress: game.address,
                ticketPrice,
                rewardConfigId: rewardConfigs.length,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const players_pool = players[0].slice(0, n_accounts);

            const scores: Record<string, [number, number]> = {};
            for (const player of players_pool) {
                scores[player.address] = [0, Number.MAX_VALUE];
            }

            for (let i = 1; i <= n_submission; ++i) {
                const player = players_pool[rng.range(n_accounts)];
                const lo = Math.floor(value_range[0] * i / n_submission);
                const hi = Math.ceil(value_range[1] * i / n_submission);
                const score = rng.intBetween(lo, hi);

                // console.log("i:", i);
                // console.log(player.address, score);

                const signature = await getSignature(potId, player);

                await callTransaction(
                    gameHub.buyTicket(potId, player.address, signature)
                );
                await gasCalculator.callTransaction(
                    gameHub.connect(game.wallet).submitScore(potId, player.address, score)
                );

                if (scores[player.address][1] === Number.MAX_VALUE) {
                    scores[player.address][0] = score;
                    scores[player.address][1] = i;
                } else if (scores[player.address][0] < score) {
                    scores[player.address][0] = score;
                    scores[player.address][1] = i;
                }

                // if (i % 10 == 0) console.log(`Finished ${i} submissions`);

                for (const player of players_pool) {
                    const score = (await gameHub.getPlayerData(potId, player.address)).score.toNumber();
                    expect(score).to.equal(scores[player.address][0]);
                }

                const topPlayers = Object.entries(scores)
                    .filter(e => e[1][1] != Number.MAX_VALUE)
                    .sort((a, b) => {
                        if (a[1][0] > b[1][0]) return -1;
                        if (a[1][0] == b[1][0]) return a[1][1] - b[1][1];
                        return 1;
                    })
                    .slice(0, rewardPortions.length)
                    .map(e => e[0]).reverse();

                const expectedTopPlayers = (await gameHub.getPotDistributions(1))[2];

                // fs.writeFileSync('tmp1.txt', JSON.stringify(topPlayers, null, 2));
                // fs.writeFileSync('tmp2.txt', JSON.stringify(expectedTopPlayers, null, 2));

                for (let i = 0; i < rewardPortions.length; ++i) {
                    expect(topPlayers[i]).to.equal(expectedTopPlayers[i]);
                }
            }

            gasCalculator.reportGas();
        }

        it('5.25.2. Case 20 accounts, 10 rewards, 500 submissions of score [-10000, 10000]', async () => {
            await testWithConfig(20, 10, 500, [-10000, 10000]);
        });

        it('5.25.3. Case 20 accounts, 10 rewards, 500 submissions of scores [-50, 50]', async () => {
            await testWithConfig(20, 10, 500, [-50, 50]);
        });

        it('5.25.4. Case 10 accounts, 1 rewards, 200 submissions of scores [-10000, 10000]', async () => {
            await testWithConfig(10, 1, 200, [-10000, 10000]);
        });

        it('5.25.5. Case 10 accounts, 1 rewards, 200 submissions of scores [-20, 20]', async () => {
            await testWithConfig(10, 1, 200, [-20, 20]);
        });

        it('5.25.6. Fail when score is not submitted by the game', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const user = players[0][1];
            const game = games[0];
            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                gameAddress: game.address,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            await expect(gameHub.connect(user).submitScore(potId, user.address, 123))
                .to.be.revertedWithCustomError(gameHub, 'Unauthorized');
        });

        it('5.25.7. Fail when pot ended', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const user = players[0][1];
            const game = games[0];
            const duration = 3600;
            const params = Object.assign(defaultCreatePotParams, {
                initialDuration: duration,
                gameAddress: game.address,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await ethers.provider.send('evm_increaseTime', [duration + 1]);
            await callTransaction(gameHub.connect(creator).closePot(potId));

            await expect(gameHub.connect(game.wallet).submitScore(potId, user.address, 123))
                .to.be.revertedWithCustomError(gameHub, 'PotEnded');
        });

        it('5.25.8. Fail when player not have ticket', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const user = players[0][1];
            const game = games[0];
            const initialDuration = 60 * 60;
            const params = Object.assign(defaultCreatePotParams, {
                initialDuration,
                gameAddress: game.address,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await expect(gameHub.connect(game.wallet).submitScore(potId, user.address, 123))
                .to.be.revertedWithCustomError(gameHub, 'NoTicket');
        });


        it('5.25.9. Test pot duration extension', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const user1 = players[0][1];
            const user2 = players[0][2];
            const game = games[0];
            const params = Object.assign(defaultCreatePotParams, {
                initialDuration: 60 * 60,
                additionalDuration: 15 * 60,
                gameAddress: game.address,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            const submitAndGetTimestamp = async (user: Wallet, score: number) => {
                await callTransaction(
                    gameHub.buyTicket(potId, user.address, await getSignature(potId, user))
                );
                const receipt1 = await gasCalculator.callTransaction(
                    gameHub.connect(game.wallet).submitScore(potId, user.address, score)
                );
                return (await ethers.provider.getBlock(receipt1.blockNumber)).timestamp;
            };

            let currentEndAt;

            // First player submit
            await ethers.provider.send('evm_increaseTime', [50 * 60]);
            const timestamp1 = await submitAndGetTimestamp(user1, 100);
            currentEndAt = (await gameHub.pots(potId)).endAt;
            expect(currentEndAt).to.be.greaterThanOrEqual(timestamp1 + 15 * 60, "1) Time should be extended correctly");

            // Second player submit but not become top
            await submitAndGetTimestamp(user2, 100);
            currentEndAt = (await gameHub.pots(potId)).endAt;
            expect(currentEndAt).to.equal(timestamp1 + 15 * 60, '2) Time should not be extended');

            // Second player submit and become top
            const timestamp2 = await submitAndGetTimestamp(user2, 200);
            currentEndAt = (await gameHub.pots(potId)).endAt;
            expect(currentEndAt).to.equal(timestamp2 + 15 * 60, '3) Time should be extended correctly');

            // Second player submit and still on top 
            await submitAndGetTimestamp(user2, 50);
            currentEndAt = (await gameHub.pots(potId)).endAt;
            expect(currentEndAt).to.equal(timestamp2 + 15 * 60, '4) Time should not be extended');

            const timestamp3 = await submitAndGetTimestamp(user2, 300);
            currentEndAt = (await gameHub.pots(potId)).endAt;
            expect(currentEndAt).to.equal(timestamp3 + 15 * 60, '5) Time should be extended correctly');
        });

        it('5.25.10. Pot duration not increase when player submit way before pot end', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const user = players[0][1];
            const game = games[0];
            const params = Object.assign(defaultCreatePotParams, {
                initialDuration: 60 * 60,
                additionalDuration: 15 * 60,
                gameAddress: game.address,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            const initialEndAt = (await gameHub.pots(potId)).endAt;

            await ethers.provider.send('evm_increaseTime', [30 * 60]);
            await callTransaction(
                gameHub.buyTicket(potId, user.address, await getSignature(potId, user))
            );
            await gasCalculator.callTransaction(
                gameHub.connect(game.wallet).submitScore(potId, user.address, 100)
            );

            let currentEndAt = (await gameHub.pots(potId)).endAt;
            expect(currentEndAt).to.be.equal(initialEndAt, "Time should not be extended")
        });
    });

    describe('5.26. closePot', async() => {
        it('5.26.1. Correctly close pot', async () => {
            await setupAlphasAndPlayers(1, 5);
            await callTransaction(
                gameHub.addNewRewardConfig([8000, 1000, 500, 500])
            );

            const alpha = alphas[0];
            const creator = players[0][0];
            const game = games[0];
            const duration = 3600;
            const ticketPrice = ethers.utils.parseEther("1");
            const alpha_players = players[0].slice(1);

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
                gameAddress: game.address,
                ticketPrice,
                feePercentage: 0,
                rewardConfigId: rewardConfigs.length,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );

            const plays = [
                [alpha_players[0], 100],
                [alpha_players[0], 100],
                [alpha_players[0], 100],
                [alpha_players[1], 100],
                [alpha_players[2], 50],
            ]

            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);
            for(const [player, score] of plays) {
                const signature = await getSignature(potId, player);
                await callTransaction(
                    gameHub.buyTicket(potId, player.address, signature)
                );
                await callTransaction(
                    gameHub.connect(game.wallet).submitScore(potId, player.address, score)
                );
            }

            const initialPlayer0Balance = await token.balanceOf(alpha_players[0].address);
            const initialPlayer1Balance = await token.balanceOf(alpha_players[1].address);
            const initialPlayer2Balance = await token.balanceOf(alpha_players[2].address);
            const initialCreatorBalance = await token.balanceOf(creator.address);

            await ethers.provider.send('evm_increaseTime', [duration + 1]);
            await callTransaction(gameHub.connect(creator).closePot(potId));

            expect((await gameHub.pots(potId)).isOpening).to.equal(false, "Pot should be closed");

            const [totalReward, remainValue, _, rewards] = await gameHub.getPotDistributions(potId);

            const expectedPlayer0Balance = initialPlayer0Balance.add(rewards[2]);
            const expectedPlayer1Balance = initialPlayer1Balance.add(rewards[1]);
            const expectedPlayer2Balance = initialPlayer2Balance.add(rewards[0]);
            const expectedCreatorBalance = initialCreatorBalance.add(remainValue);

            expect(await token.balanceOf(alpha_players[0].address)).to.equal(expectedPlayer0Balance, "Incorrect player 0 balance after closing pot");
            expect(await token.balanceOf(alpha_players[1].address)).to.equal(expectedPlayer1Balance, "Incorrect player 1 balance after closing pot");
            expect(await token.balanceOf(alpha_players[2].address)).to.equal(expectedPlayer2Balance, "Incorrect player 2 balance after closing pot");
            expect(await token.balanceOf(creator.address)).to.equal(expectedCreatorBalance, "Incorrect creator balance after closing pot");

            const filter = gameHub.filters.PotClosure();
            const events = await gameHub.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 PotClosure events");

            const expectedEvent = {
                potId,
                totalReward,
                remainValue,
            };
            verifyContractData(events[0].args, expectedEvent, "PotClosure event");
        });

        it('5.26.2. Close pot when there is no player', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const duration = 3600;
            const initialValue = ethers.utils.parseEther("10");

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
                initialValue,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            const initialCreatorBalance = await token.balanceOf(creator.address);

            await ethers.provider.send('evm_increaseTime', [duration + 1]);
            await callTransaction(gameHub.connect(creator).closePot(potId));

            const expectedCreatorBalance = initialCreatorBalance.add(initialValue);
            expect(await token.balanceOf(creator.address)).to.equal(expectedCreatorBalance, "Incorrect creator balance after closing pot");

            const filter = gameHub.filters.PotClosure();
            const events = await gameHub.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 PotClosure events");

            const expectedEvent = {
                potId,
                totalReward: ethers.constants.Zero,
                remainValue: initialValue,
            };
            verifyContractData(events[0].args, expectedEvent, "PotClosure event");
        });

        it('5.26.3. Fail when time is not over', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const duration = 3600;

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await expect(gameHub.connect(creator).closePot(potId))
                .to.be.revertedWithCustomError(gameHub, 'PotNotEnded');
        });

        it('5.26.4. Fail when pot is closed twice', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const duration = 3600;

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await ethers.provider.send('evm_increaseTime', [duration + 1]);
            await callTransaction(gameHub.connect(creator).closePot(potId));
            await expect(gameHub.connect(creator).closePot(potId))
                .to.be.revertedWithCustomError(gameHub, 'PotAlreadyClosed');
        });
    });

    describe('5.27. forceClosePot', async() => {
        it('5.27.1. Close pot even when time is not over', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const duration = 3600;

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await callTransaction(gameHub.connect(owner).forceClosePot(potId));
            expect((await gameHub.pots(potId)).isOpening).to.equal(false, "Pot should be closed");
        });

        it('5.27.2. Fail when caller is not owner', async () => {
            const alpha = alphas[0];
            const creator = players[0][0];
            const duration = 3600;

            const params = Object.assign(defaultCreatePotParams, {
                creator: creator.address,
                alpha: alpha.address,
                initialDuration: duration,
            });
            await callTransaction(
                gameHub.connect(creator).createPot(...params.toArray())
            );
            const potId = await gameHub.getLatestPotIdOfAlpha(alpha.address);

            await expect(gameHub.connect(creator).forceClosePot(potId))
                .to.be.revertedWith('Ownable: caller is not the owner');
        });
    });
});