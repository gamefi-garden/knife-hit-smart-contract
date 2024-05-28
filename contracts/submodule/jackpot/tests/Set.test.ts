import {ethers, upgrades} from "hardhat";
import {expect} from "chai";
import Random from "random-seed";
import {
    TestSet,
    TestSet__factory,
} from "../typechain-types";
import {GasCalculator, RandomUtils, isSameElements, isEqualArray} from "./helper";

let Set: TestSet__factory, set: TestSet;
let owner: any, players: any[];
let rng: Random.RandomSeed, randUtils: RandomUtils;

let gasCalculator: GasCalculator;

describe('3. Set', async () => {
    before(async () => {
        Set = await ethers.getContractFactory('TestSet');
        gasCalculator = new GasCalculator();

        const seed = Date.now().toString();
        console.log(`Seed: ${seed}`);
        rng = Random.create(seed);
        randUtils = new RandomUtils(rng);
    });

    beforeEach(async () => {
        set = await upgrades.deployProxy(Set) as TestSet;
        await set.deployed();

        [owner] = await ethers.getSigners();

        gasCalculator.reset();

        players = [];
        for (let i = 0; i < 1000; ++i) {
            players.push(new ethers.Wallet(
                ethers.utils.id(i.toString()),
                ethers.provider
            ));
        }
    });

    describe('3.1. Insert', async () => {
        async function testInsert(n_addresses: number) {
            const addresses = players.slice(0, n_addresses).map(p => p.address);
            for (let i = 0; i < n_addresses; ++i) {
                await gasCalculator.callTransaction(set.connect(owner).insert(addresses[i]));
            }

            gasCalculator.reportGas();

            const set_addresses: string[] = await (set.allValues());
            expect(isEqualArray(addresses, set_addresses)).to.equal(true, 'Set addresses not same as inserted addresses');
        }

        it('3.1.1 Random insert 50 addresses', async () => {
            await testInsert(50);
        });

        it('3.1.2 Revert insert duplicated address', async () => {
            await set.connect(owner).insert(players[0].address);
            await expect(set.connect(owner).insert(players[0].address)).to.be.revertedWithCustomError(
                set,
                `DuplicatedSetValue`,
            );
        });
    });

    describe('3.2. HasValue', async () => {
        async function testHasValue(n_addresses: number) {
            const addresses = players.slice(0, n_addresses).map(p => p.address);
            for (let i = 0; i < n_addresses; ++i) {
                await set.connect(owner).insert(addresses[i]);
            }

            for (let i = 0; i < n_addresses; ++i) {
                expect(await set.hasValue(addresses[i])).to.equal(true, 'Set not has pushed address');
            }
            expect(await set.hasValue(players[n_addresses].address)).to.equal(false, 'Set has addresses that is not pushed into set');
        }

        it('3.2.1 Random hasValue of 50 addresses', async () => {
            await testHasValue(50);
        });
    });

    describe('3.3. Erase', async () => {
        async function testErase(n_addresses: number) {
            const addresses = players.slice(0, n_addresses).map(p => p.address);
            for (let i = 0; i < n_addresses; ++i) {
                await set.connect(owner).insert(addresses[i]);
            }

            const random_addresses = [...addresses];
            randUtils.shuffle(random_addresses);

            for (let i = 0; i < n_addresses; ++i) {
                const address = random_addresses[i];
                await gasCalculator.callTransaction(set.connect(owner).erase(address));
                const set_addresses: string[] = await (set.allValues());
                expect(isSameElements(random_addresses.slice(i + 1), set_addresses)).to.equal(true, 'Incorrect remaining set addresses');
            }

            gasCalculator.reportGas();
        }

        it('3.3.1 Random erase of 50 addresses', async () => {
            await testErase(50);
        });

        it('3.3.2 Revert erase of address not in set', async () => {
            await set.connect(owner).insert(players[0].address);
            await expect(set.connect(owner).erase(players[1].address)).to.be.revertedWithCustomError(
                set,
                `SetValueNotFound`,
            );
        });

        it('3.3.3 Revert second erase of address in set', async () => {
            await set.connect(owner).insert(players[0].address);
            await set.connect(owner).erase(players[0].address);
            await expect(set.connect(owner).erase(players[0].address)).to.be.revertedWithCustomError(
                set,
                `SetValueNotFound`,
            );
        });
    });

    describe('3.4. isEmpty', async () => {
        async function testIsEmpty(n_addresses: number) {
            const addresses = players.slice(0, n_addresses).map(p => p.address);

            expect(await set.isEmpty()).to.equal(true, "Initial set should be empty");
            for (let i = 0; i < n_addresses; ++i) {
                await set.connect(owner).insert(addresses[i]);
                expect(await set.isEmpty()).to.equal(false, "Set after inserting elements should not be empty");
            }

            for (let i = 0; i < n_addresses - 1; ++i) {
                await set.connect(owner).erase(addresses[i]);
                expect(await set.isEmpty()).to.equal(false, "Set after deleting first n - 1 elements should not be empty");
            }

            await set.connect(owner).erase(addresses[n_addresses - 1]);
            expect(await set.isEmpty()).to.equal(true, "Set after deleting last element should be empty");
        }

        it('3.4.1 isEmpty after insert and delete 50 random addresses', async () => {
            await testIsEmpty(50);
        });
    });

    describe('3.5. size', async () => {
        async function testSize(n_addresses: number) {
            const addresses = players.slice(0, n_addresses).map(p => p.address);

            expect(await set.size()).to.equal(0, "Initial set size should be 0");
            for (let i = 0; i < n_addresses; ++i) {
                await set.connect(owner).insert(addresses[i]);
                expect(await set.size()).to.equal(i + 1, "Incorrect set size after inserting elements");
            }

            for (let i = 0; i < n_addresses; ++i) {
                await set.connect(owner).erase(addresses[i]);
                expect(await set.size()).to.equal(n_addresses - i - 1, "Incorrect set size after deleting elements");
            }
        }

        it('3.5.1 size after insert and delete 50 random addresses', async () => {
            await testSize(50);
        });
    });

    describe('3.6. Full flow test', async () => {
        const QueryType = {
            INSERT: 0,
            ERASE: 1,
        };

        async function testFullflow(n_addresses: number, n_query: number) {
            let address_in_set: any[] = [];
            let address_not_in_set: any[] = players.slice(0, n_addresses).map(p => p.address);

            const add_to_set = (address: string) => {
                address_in_set.push(address);
                address_not_in_set = address_not_in_set.filter(a => a != address);
            }
            const erase_from_set = (address: string) => {
                address_in_set = address_in_set.filter(a => a != address);
                address_not_in_set.push(address);
            }

            for (let i = 1; i <= n_query; ++i) {
                let type;
                if (address_in_set.length == 0) {
                    type = QueryType.INSERT;
                } else if (address_not_in_set.length == 0) {
                    type = QueryType.ERASE;
                } else {
                    type = rng.intBetween(0, 1);
                }

                if (type == QueryType.INSERT) {
                    const address = randUtils.sample(address_not_in_set);
                    add_to_set(address);
                    await gasCalculator.callTransaction(set.connect(owner).insert(address));
                } else if (type == QueryType.ERASE) {
                    const address = randUtils.sample(address_in_set);
                    erase_from_set(address);
                    await gasCalculator.callTransaction(set.connect(owner).erase(address));
                }

                const set_addresses: string[] = await (set.allValues());
                expect(isSameElements(address_in_set, set_addresses)).to.equal(true, 'Incorrect set addresses');
            }

            gasCalculator.reportGas();
        }

        it('3.6.1 Random 1000 operations of 20 addresses', async () => {
            await testFullflow(20, 1000);
        });
    });
});