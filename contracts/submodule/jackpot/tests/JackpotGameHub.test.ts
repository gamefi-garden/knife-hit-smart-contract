import {ethers, upgrades} from "hardhat";
import {expect} from "chai";
import Random from "random-seed";
import {
    JackpotGameHub,
    JackpotGameHub__factory,
    TestAlphaKeysFactory,
    TestAlphaKeysFactory__factory,
    TestToken,
    TestToken__factory
} from "../typechain-types";
import {BigNumber, ContractTransaction, ContractReceipt} from "ethers";

let Jackpot: JackpotGameHub__factory, jackpot: JackpotGameHub;
let AlphaKeysFactory: TestAlphaKeysFactory__factory, alphaFactory: TestAlphaKeysFactory;
let Token: TestToken__factory, token: TestToken;
let treasury: any, operationFund: any, game: any, players: any[], rewardPortions: number[];
let rng: Random.RandomSeed;

let totalGas: BigNumber;
let maxGasConsumed: BigNumber;
let minGasConsumed: BigNumber;
let transactionCount: number;

const callTransaction = async (transaction: Promise<ContractTransaction>, calculateGas = false): Promise<ContractReceipt> => {
    const receipt = await (await transaction).wait();
    if (calculateGas) {
        const gasConsumed = receipt.gasUsed;

        totalGas = totalGas.add(gasConsumed);

        if (gasConsumed.gt(maxGasConsumed)) {
            maxGasConsumed = gasConsumed;
        }

        if (gasConsumed.lt(minGasConsumed)) {
            minGasConsumed = gasConsumed;
        }

        transactionCount++;
    }
    return receipt;
}

describe('1. JackpotGameHub', async () => {
    before(async () => {
        Jackpot = await ethers.getContractFactory('JackpotGameHub');
        AlphaKeysFactory = await ethers.getContractFactory('TestAlphaKeysFactory');
        Token = await ethers.getContractFactory('TestToken');
    });

    describe('1.1. Full flow test', async () => {
        beforeEach(async () => {
            const accounts = await ethers.getSigners();
            treasury = accounts[0];
            operationFund = accounts[1];
            game = accounts[2];

            players = [];
            for (let i = 0; i < 1000; ++i) {
                players.push(new ethers.Wallet(
                    ethers.utils.id(i.toString()),
                    ethers.provider
                ));
                await treasury.sendTransaction({
                    to: players[i].address,
                    value: ethers.utils.parseEther('20')
                });
            }

            alphaFactory = await upgrades.deployProxy(AlphaKeysFactory) as TestAlphaKeysFactory;
            token = await upgrades.deployProxy(Token, ['Name', 'SYMBOL']) as TestToken;
            await callTransaction(token.mintFor(players.map(player => player.address), 1000));

            const operationFundPercentage = 10;
            const reservePercentage = 20;

            rewardPortions = [];
            for (let i = 0; i < 100; ++i) rewardPortions.push(Math.ceil(Math.random() * 100));

            jackpot = await upgrades.deployProxy(
                Jackpot,
                [
                    alphaFactory.address,
                    treasury.address,
                    operationFund.address,
                    operationFundPercentage,
                    reservePercentage,
                    rewardPortions,
                ]
            ) as JackpotGameHub;
            await jackpot.deployed();

            await jackpot.registerGame(
                game.address,
                3600,
                10
            );

            const seed = Date.now().toString();
            console.log(`Seed: ${seed}`);
            rng = Random.create(seed);

            totalGas = BigNumber.from(0);
            maxGasConsumed = BigNumber.from(0);
            minGasConsumed = ethers.BigNumber.from(ethers.constants.MaxUint256)
            transactionCount = 0;
        });

        it('1.1.1. Each player plays solo', async () => {
            const ticketPrice = 1;

            await jackpot.createNewPot(
                ticketPrice,
                1000000,
                0,
                1,
                0,
            );

            const scores: Record<string, [number, number]> = {};
            for (const player of players) {
                scores[player.address] = [0, Number.MAX_VALUE];
            }

            for (let i = 1; i <= 5000; ++i) {
                const player = players[rng.intBetween(0, players.length - 1)];
                const score = rng.intBetween(-10000, 10000);

                await callTransaction(jackpot.connect(player).buyTicket({value: ticketPrice}));
                await callTransaction(jackpot.connect(game).submitScore(player.address, score));
                scores[player.address][0] += score;
                scores[player.address][1] = i;

                if (i % 100 == 0) console.log(`Finished ${i} submissions`);
            }

            console.log(`Total gas consumed: ${totalGas.toString()}`);
            console.log(`Average gas consumed: ${totalGas.div(transactionCount).toString()}`);
            console.log(`Max gas consumed: ${maxGasConsumed.toString()}`);
            console.log(`Min gas consumed: ${minGasConsumed.toString()}`)

            for (const player of players) {
                const score = (await jackpot.getPotPlayer(1, player.address)).score.toNumber();
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

            const expectedTopPlayers = (await jackpot.getPotDistributions(1))[2];

            // fs.writeFileSync('tmp1.txt', JSON.stringify(topPlayers, null, 2));
            // fs.writeFileSync('tmp2.txt', JSON.stringify(expectedTopPlayers, null, 2));

            for (let i = 0; i < rewardPortions.length; ++i) {
                expect(topPlayers[i]).to.equal(expectedTopPlayers[i]);
            }
        });
    });



});