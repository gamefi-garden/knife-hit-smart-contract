import {ethers, upgrades} from "hardhat";
import {expect} from "chai";
import Random from "random-seed";
import {GameLibrary, GameLibrary__factory} from "../typechain-types";
import {BigNumber, ContractTransaction, ContractReceipt} from "ethers";
import * as fs from "fs";
import {GasCalculator, RandomUtils, callTransaction, isSameElements, isEqualArray, expectViewToBeRevertedWithCustomError} from "./helper";
import { mine } from "@nomicfoundation/hardhat-network-helpers";

let GameLib: GameLibrary__factory, gameLib: GameLibrary;
let rng: Random.RandomSeed, randUtils: RandomUtils;
let owner: any, notOwner: any, wallets: any;
let mockGames: [string, string, BigNumber, number, number][];
let gasCalculator: GasCalculator;
let n_mockGames = 10;

describe('1. GameLibrary', async () => {
    before(async () => {
        GameLib = await ethers.getContractFactory('GameLibrary');
        gasCalculator = new GasCalculator();

        const seed = Date.now().toString();
        console.log(`Seed: ${seed}`);
        rng = Random.create(seed);
        randUtils = new RandomUtils(rng);
    });

    beforeEach(async () => {
        gameLib = await upgrades.deployProxy(GameLib) as GameLibrary;
        await gameLib.deployed();

        wallets = [];
        for (let i = 0; i < n_mockGames; ++i) {
            wallets.push(new ethers.Wallet(
                ethers.utils.id(i.toString()),
                ethers.provider
            ));
        }

        mockGames = [];
        for (let i = 0; i < n_mockGames; ++i) {
            mockGames.push([
                wallets[i].address,
                `Mock Game ${i}`,
                ethers.utils.parseEther("1"),
                900,
                10,
            ]);
        }

        [owner, notOwner] = await ethers.getSigners();

        gasCalculator.reset();
    });
    
    describe('1.1. initialize()', async () => {
        it('1.1.1. correct state after initialize', async() => {
            expect(await gameLib.owner()).to.equal(owner.address, "Incorrect owner after initialize"); 
        });
    });

    describe('1.2. version()', async() => {
        it('1.2.1. correct version', async() => {
            expect(await gameLib.version()).to.equal("v0.0.1", "Incorrect version"); 
        });
    });

    describe('1.3. updateGameName(address, string)', async () => {
        it('1.3.1. correct new game name', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await callTransaction(
                gameLib.connect(owner).updateGameName(wallets[0].address, "New Game")
            );

            const game = await gameLib.games(wallets[0].address);
            expect(game.name).to.equal("New Game", "Incorrect new game name");

            const filter = gameLib.filters.GameNameUpdate();
            const events = await gameLib.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 GameNameUpdate events");
            expect(events[0].args.gameAddress).to.equal(wallets[0].address, "Incorrect event gameAddress")
            expect(events[0].args.newValue).to.equal("New Game", "Incorrect event newValue")
        });

        it('1.3.2. fail when change name of unregistered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await expect(gameLib.connect(owner).updateGameName(
                wallets[1].address, 
                "New Game",
            )).to.be.revertedWithCustomError(gameLib, `UnregisteredGame`);
        });

        it('1.3.3. ownerOnly', async() => {         
            await expect(gameLib.connect(notOwner).updateGameName(
                wallets[0].address, 
                "New Game",
            )).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe('1.4. updateGameDefaultAdditionalDuration(address, uint40)', async () => {
        it('1.4.1. correct new game defaultAdditionalDuration', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await callTransaction(
                gameLib.connect(owner).updateGameDefaultAdditionalDuration(wallets[0].address, 600)
            );

            const game = await gameLib.games(wallets[0].address);
            expect(game.defaultAdditionalDuration).to.equal(600, "Incorrect new game defaultAdditionalDuration");

            const filter = gameLib.filters.GameDefaultAdditionalDurationUpdate();
            const events = await gameLib.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 GameDefaultAdditionalDurationUpdate events");
            expect(events[0].args.gameAddress).to.equal(wallets[0].address, "Incorrect event gameAddress")
            expect(events[0].args.newValue).to.equal(600, "Incorrect event newValue")
        });

        it('1.4.2. fail when change name of unregistered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await expect(gameLib.connect(owner).updateGameDefaultAdditionalDuration(
                wallets[1].address, 
                600,
            )).to.be.revertedWithCustomError(gameLib, `UnregisteredGame`);
        });

        it('1.4.3. ownerOnly', async() => {         
            await expect(gameLib.connect(notOwner).updateGameDefaultAdditionalDuration(
                wallets[0].address, 
                600,
            )).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe('1.5. updateGameDefaultFeePercentage(address, uint8)', async () => {
        it('1.5.1. correct new game defaultFeePercentage', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await callTransaction(
                gameLib.connect(owner).updateGameDefaultFeePercentage(wallets[0].address, 20)
            );

            const game = await gameLib.games(wallets[0].address);
            expect(game.defaultFeePercentage).to.equal(20, "Incorrect new game defaultFeePercentage");

            const filter = gameLib.filters.GameDefaultFeePercentageUpdate();
            const events = await gameLib.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 GameDefaultFeePercentageUpdate events");
            expect(events[0].args.gameAddress).to.equal(wallets[0].address, "Incorrect event gameAddress")
            expect(events[0].args.newValue).to.equal(20, "Incorrect event newValue")
        });

        it('1.5.2. fail when change name of unregistered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await expect(gameLib.connect(owner).updateGameDefaultFeePercentage(
                wallets[1].address, 
                20,
            )).to.be.revertedWithCustomError(gameLib, `UnregisteredGame`);
        });

        it('1.5.3. ownerOnly', async() => {         
            await expect(gameLib.connect(notOwner).updateGameDefaultFeePercentage(
                wallets[0].address, 
                20,
            )).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe('1.6. updateGameDefaultTicketPrice(address, uint256)', async () => {
        it('1.6.1. correct new game defaultTicketPrice', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await callTransaction(
                gameLib.connect(owner).updateGameDefaultTicketPrice(wallets[0].address, 20)
            );

            const game = await gameLib.games(wallets[0].address);
            expect(game.defaultTicketPrice).to.equal(20, "Incorrect new game defaultTicketPrice");

            const filter = gameLib.filters.GameDefaultTicketPriceUpdate();
            const events = await gameLib.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 GameDefaultTicketPriceUpdate events");
            expect(events[0].args.gameAddress).to.equal(wallets[0].address, "Incorrect event gameAddress")
            expect(events[0].args.newValue).to.equal(20, "Incorrect event newValue")
        });

        it('1.6.2. fail when change name of unregistered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await expect(gameLib.connect(owner).updateGameDefaultTicketPrice(
                wallets[1].address, 
                20,
            )).to.be.revertedWithCustomError(gameLib, `UnregisteredGame`);
        });

        it('1.6.3. ownerOnly', async() => {         
            await expect(gameLib.connect(notOwner).updateGameDefaultTicketPrice(
                wallets[0].address, 
                20,
            )).to.be.revertedWith("Ownable: caller is not the owner");
        });

    });

    describe('1.7. getRegisteredGames()', async () => {
        it('1.7.1. correctly return registered game', async() => {
            expect(isSameElements(
                await gameLib.getRegisteredGames(), 
                [],
            )).to.equal(true, "Incorrect before game registration");

            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            expect(isSameElements(
                await gameLib.getRegisteredGames(), 
                [wallets[0].address],
            )).to.equal(true, "Incorrect after 1st game registered");

            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[1].address,
                "Game 1",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            expect(isSameElements(
                await gameLib.getRegisteredGames(), 
                [wallets[0].address, wallets[1].address],
            )).to.equal(true, "Incorrect after 2nd game registered");
        });
    });

    describe('1.8. registerGame(address, string, uint256, uint40, uint8)', async () => {
        it('1.8.1. register game correctly', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));

            const game = await gameLib.games(wallets[0].address); 
            expect(game.name).to.equal("Game 0", "Incorrected registered game name");
            expect(game.defaultTicketPrice).to.equal(ethers.utils.parseEther("1"), "Incorrected registered game defaultTicketPrice");
            expect(game.defaultAdditionalDuration).to.equal(900, "Incorrected registered game defaultAdditionalDuration");
            expect(game.defaultFeePercentage).to.equal(10, "Incorrected registered game defaultFeePercentage");

            const filter = gameLib.filters.GameRegistration();
            const events = await gameLib.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 GameRegistration events");
            expect(events[0].args.gameAddress).to.equal(wallets[0].address, "Incorrect event gameAddress")
            expect(events[0].args.name).to.equal("Game 0", "Incorrect event name")
            expect(events[0].args.defaultTicketPrice).to.equal(ethers.utils.parseEther("1"), "Incorrect event defaultTicketPrice")
            expect(events[0].args.defaultAdditionalDuration).to.equal(900, "Incorrect event defaultAdditionalDuration")
            expect(events[0].args.defaultFeePercentage).to.equal(10, "Incorrect event defaultFeePercentage")
        });

        it('1.8.2. ownerOnly', async() => {
            await (expect(gameLib.connect(notOwner).registerGame(
                ...mockGames[0],
            ))).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it('1.8.3. fail after register a game twice', async() => {
            await callTransaction(
                gameLib.connect(owner).registerGame(...mockGames[0])
            );
            await (expect(gameLib.connect(owner).registerGame(
                ...mockGames[0],
            ))).to.be.revertedWithCustomError(gameLib, `GameAlreadyRegistered`);
        });

        it('1.8.4. fail when defaultTicketPrice is 0', async() => {
            await (expect(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("0"),
                900,
                10,
            ))).to.be.revertedWithCustomError(gameLib, `InvalidParams`);
        });

        it('1.8.5. fail when defaultFeePercentage is greater than 100', async() => {
            await (expect(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                101,
            ))).to.be.revertedWithCustomError(gameLib, `InvalidParams`);
        });
    });

    describe('1.9. removeGame(address)', async () => {
        it('1.9.1. correctly remove game', async() => {
            expect(await gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            expect(await gameLib.connect(owner).registerGame(
                wallets[1].address,
                "Game 1",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));

            await callTransaction(gameLib.connect(owner).removeGame(wallets[0].address));
            
            expect(isSameElements(
                await gameLib.getRegisteredGames(), 
                [wallets[1].address],
            )).to.equal(true, "Incorrect registered games after game remove");

            const filter = gameLib.filters.GameRemoval();
            const events = await gameLib.queryFilter(filter);
            expect(events.length).to.equal(1, "There should be 1 GameRemoval events");
            expect(events[0].args.gameAddress).to.equal(wallets[0].address, "Incorrect event gameAddress")
        });

        it('1.9.2. fail when remove unregistered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            
            await expect(gameLib.connect(owner).removeGame(
                wallets[1].address, 
            )).to.be.revertedWithCustomError(gameLib, `UnregisteredGame`);
        });

        it('1.9.3. ownerOnly', async() => {         
            await expect(gameLib.connect(notOwner).removeGame(
                wallets[0].address, 
            )).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe('1.10. getGameNumber()', async () => {
        it('1.10.1. correct game number', async() => {
            expect(await gameLib.getGameNumber()).to.equal(0, "Incorrect when no game registered");

            await callTransaction(gameLib.connect(owner).registerGame(...mockGames[0]));
            expect(await gameLib.getGameNumber()).to.equal(1, "Incorrect after 1 game registered");

            await callTransaction(gameLib.connect(owner).registerGame(...mockGames[1]));
            expect(await gameLib.getGameNumber()).to.equal(2, "Incorrect after 2 game registered");
        });
    });

    describe('1.11. getGame(address)', async () => {
        it('1.11.1. correctly get registered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));

            const game = await gameLib.getGame(wallets[0].address) 
            expect(game.name).to.equal("Game 0", "Incorrected registered game name");
            expect(game.defaultTicketPrice).to.equal(ethers.utils.parseEther("1"), "Incorrected registered game defaultTicketPrice");
            expect(game.defaultAdditionalDuration).to.equal(900, "Incorrected registered game defaultAdditionalDuration");
            expect(game.defaultFeePercentage).to.equal(10, "Incorrected registered game defaultFeePercentage");
        });

        it('1.11.2. fail when get unregistered game', async() => {
            await callTransaction(gameLib.connect(owner).registerGame(
                wallets[0].address,
                "Game 0",
                ethers.utils.parseEther("1"),
                900,
                10,
            ));
            await expectViewToBeRevertedWithCustomError(
                gameLib.getGame(wallets[1].address),
                GameLib,
                `UnregisteredGame`,
            );
        });
    });

    describe('1.12. getRandomGameAddress()', async () => {
        it('1.12.1. correctly return random game address', async() => {
            for(let i = 0; i < n_mockGames; ++i) {
                await callTransaction(
                    gameLib.connect(owner).registerGame(...mockGames[i],
                ));
            }

            const hit_addresses: string[] = [];
            for(let i = 0; i <= 200; ++i) {
                const address = await gameLib.getRandomGameAddress();
                expect(mockGames.map(g => g[0]).includes(address))
                    .to.equal(true, "Random game address should be in registered game list");
                if (!hit_addresses.includes(address)) {
                    hit_addresses.push(address);
                }
                await mine(1);
            }

            expect(hit_addresses.length).to.equal(n_mockGames, "All registered should be returned at least once");
        });

        it('1.12.2. fail when no game registered', async() => {
            await expect(gameLib.getRandomGameAddress()).to.be.reverted;
            // await expectViewToBeRevertedWithCustomError(
            //     gameLib.getRandomGameAddress(),
            //     GameLib,
            //     `NoRegisteredGame`,
            // );
        });
    });
});