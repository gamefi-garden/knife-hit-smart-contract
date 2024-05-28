import {ethers, upgrades} from "hardhat";
import {expect} from "chai";
import Random from "random-seed";
import {TestHeap, TestHeap__factory,} from "../typechain-types";
import {GasCalculator, isSameElements, RandomUtils} from "./helper";

let Heap: TestHeap__factory, heap: TestHeap;
let owner: any, players: any[];
let rng: Random.RandomSeed, randUtils: RandomUtils;

let gasCalculator: GasCalculator;

export class MapWithDefault<K, V> extends Map<K, V> {
    default: (key: K) => V;

    constructor(defaultFunction: (key: K) => V) {
        super();
        this.default = defaultFunction;
    }

    get(key: K): V {
        if (!this.has(key)) {
            return this.default(key);
        }
        return super.get(key) as V;
    }
}

function checkHeapProperties(addresses: string[], values: MapWithDefault<string, number>) {
    for (let i = 0; i < addresses.length; ++i) {
        let address_i = addresses[i];
        let value_i = values.get(address_i);
        let left = 2 * i + 1;
        if (left < addresses.length) {
            let address_left = addresses[left];
            let value_left = values.get(address_left);
            if (address_i == address_left || value_i < value_left) return false;
        }
        let right = 2 * i + 2;
        if (right < addresses.length) {
            let address_right = addresses[right];
            let value_right = values.get(address_right);
            if (address_i == address_right || value_i < value_right) return false;
        }
    }
    return true;
}

function printHeap(heap_addresses: string[], values: MapWithDefault<string, number>) {
    let i = 0;
    let sz = 1;
    while (i < heap_addresses.length) {
        const layer = heap_addresses.slice(i, i + sz).map(a => values.get(a));
        console.log(layer.join(' '));
        i += sz;
        sz *= 2;
    }
}

describe('2. Heap', async () => {
    before(async () => {
        Heap = await ethers.getContractFactory('TestHeap');
        gasCalculator = new GasCalculator();

        const seed = Date.now().toString();
        console.log(`Seed: ${seed}`);
        rng = Random.create(seed);
        randUtils = new RandomUtils(rng);
    });

    beforeEach(async () => {
        heap = await upgrades.deployProxy(Heap) as TestHeap;
        await heap.deployed();

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

    describe('2.1. Push', async () => {
        async function testPush(vals: number[]) {
            const n_values = vals.length;

            const addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await gasCalculator.callTransaction(heap.connect(owner).push(addresses[i]));
                const heap_addresses: string[] = await (heap.allValues());
                expect(checkHeapProperties(heap_addresses, values)).to.equal(true, 'Heap properties not satisfied');
            }

            gasCalculator.reportGas();

            const heap_addresses: string[] = await (heap.allValues());
            expect(isSameElements(addresses, heap_addresses)).to.equal(true, 'Heap addresses not same as pushed addresses');
        }

        it('2.1.1 Random push 50 addresses with value [1, 10000]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testPush(values);
        });

        it('2.1.2 Random push 50 addresses with value [1, 5]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 5));
            }
            await testPush(values);
        });

        it('2.1.3 Revert push duplicated address', async () => {
            await heap.connect(owner).setValue(players[0].address, 5);
            await heap.connect(owner).push(players[0].address);
            await expect(heap.connect(owner).push(players[0].address)).to.be.revertedWithCustomError(
                heap,
                `DuplicatedHeapValue`,
            );
        });
    });

    describe('2.2. Peek', async () => {
        async function testPeek(vals: number[]) {
            const n_values = vals.length;

            const addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }

            const top_address: string = await (heap.peek());

            addresses.sort((a, b) => values.get(b) - values.get(a));
            expect(top_address).to.equal(addresses[0], 'Peeked address not have highest value');
        }

        it('2.2.1 Random peek of 50 addresses with value [1, 10000]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testPeek(values);
        });

        it('2.2.2 Random peek of 50 addresses with value [1, 5]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testPeek(values);
        });

        it('2.2.3 Revert empty heap peek', async () => {
            await expect(heap.peek()).to.be.revertedWithCustomError(
                heap,
                `EmptyHeap`,
            );
        });
    });


    describe('2.3. Pop', async () => {
        async function testPop(vals: number[]) {
            const n_values = vals.length;
            let addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                const address = await heap.peek();
                await gasCalculator.callTransaction(heap.connect(owner).pop());
                addresses = addresses.filter(a => a != address);

                const heap_addresses: string[] = await (heap.allValues());
                expect(isSameElements(addresses, heap_addresses)).to.equal(true, 'Incorrect remaining heap addresses');
                expect(checkHeapProperties(heap_addresses, values)).to.equal(true, 'Heap after pop not has heap properties');
            }

            gasCalculator.reportGas();
        }

        it('2.3.1 Random pop of 50 addresses with value [1, 10000]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testPop(values);
        });

        it('2.3.2 Random pop of 50 addresses with value [1, 5]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testPop(values);
        });

        it('2.3.3 Revert empty heap pop', async () => {
            await expect(heap.pop()).to.be.revertedWithCustomError(
                heap,
                `EmptyHeap`,
            );
        });

        it('2.3.4 Revert pop after popping all elements from heap', async () => {
            const n_values = 50;

            let addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                const val = rng.intBetween(1, 10);
                values.set(addresses[i], val);
                await heap.connect(owner).setValue(addresses[i], val);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).pop();
            }
            await expect(heap.pop()).to.be.revertedWithCustomError(
                heap,
                `EmptyHeap`,
            );
        });
    });

    describe('2.4. HasValue', async () => {
        async function testHasValue(vals: number[]) {
            const n_values = vals.length;
            const addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }
            for (let i = 0; i < n_values; ++i) {
                expect(await heap.hasValue(addresses[i])).to.equal(true, 'Heap not has pushed address');
            }
            expect(await heap.hasValue(players[n_values].address)).to.equal(false, 'Heap has addresses that is not pushed into heap');
        }

        it('2.4.1 Random hasValue of 50 addresses', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testHasValue(values);
        });
    });


    describe('2.5. Remove', async () => {
        async function testRemove(vals: number[]) {
            const n_values = vals.length;
            const addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }

            const random_addresses = [...addresses];
            randUtils.shuffle(random_addresses);

            for (let i = 0; i < n_values; ++i) {
                const address = random_addresses[i];
                await gasCalculator.callTransaction(heap.connect(owner).remove(address));
                const heap_addresses: string[] = await (heap.allValues());
                expect(isSameElements(random_addresses.slice(i + 1), heap_addresses)).to.equal(true, 'Incorrect remaining heap addresses');
                expect(checkHeapProperties(heap_addresses, values)).to.equal(true, 'Heap after remove not has heap properties');
            }
        }

        it('2.5.1 Random remove of 50 addresses with value [1, 10000]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 10000));
            }
            await testRemove(values);
        });

        it('2.5.2 Random remove of 50 addresses with value [1, 5]', async () => {
            const values = [];
            for (let i = 1; i <= 50; ++i) {
                values.push(rng.intBetween(1, 5));
            }
            await testRemove(values);
        });

        it('2.5.3 Revert remove of address not in heap', async () => {
            await heap.connect(owner).setValue(players[0].address, 5);
            await heap.connect(owner).push(players[0].address);
            await expect(heap.connect(owner).remove(players[1].address)).to.be.revertedWithCustomError(
                heap,
                `HeapValueNotFound`,
            );
        });


        it('2.5.4 Revert second remove of address in heap', async () => {
            await heap.connect(owner).setValue(players[0].address, 5);
            await heap.connect(owner).push(players[0].address);
            await heap.connect(owner).remove(players[0].address);
            await expect(heap.connect(owner).remove(players[0].address)).to.be.revertedWithCustomError(
                heap,
                `HeapValueNotFound`,
            );
        });
    });

    describe('2.6. Up', async () => {
        async function testUpHeap(vals: number[], queries: [string, number][]) {
            const n_values = vals.length;
            const addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }

            for (const [address, delta] of queries) {
                values.set(address, values.get(address) + delta);
                await gasCalculator.callTransaction(heap.connect(owner).setValue(address, values.get(address)));
                await gasCalculator.callTransaction(heap.connect(owner).up(address));
                const heap_addresses: string[] = await (heap.allValues());
                expect(checkHeapProperties(heap_addresses, values)).to.equal(true, 'Heap after remove not has heap properties');
            }
        }

        it('2.6.1 Random 200 up heap with value [1, 10000] of 20 addresses', async () => {
            const values = [];
            for (let i = 1; i <= 20; ++i) {
                values.push(0);
            }
            const queries: [string, number][] = [];
            for (let i = 1; i <= 200; ++i) {
                const address = players[rng.range(20)].address;
                const delta = rng.intBetween(1, 10000);
                queries.push([address, delta]);
            }
            await testUpHeap(values, queries);
        });

        it('2.6.2 Random 200 up heap with value [0, 1] of 20 addresses', async () => {
            const values = [];
            for (let i = 1; i <= 20; ++i) {
                values.push(0);
            }
            const queries: [string, number][] = [];
            for (let i = 1; i <= 200; ++i) {
                const address = players[rng.range(20)].address;
                const delta = rng.intBetween(0, 1);
                queries.push([address, delta]);
            }
            await testUpHeap(values, queries);
        });

        it('2.6.3 Revert up heap of address not in heap', async () => {
            await heap.connect(owner).setValue(players[0].address, 5);
            await heap.connect(owner).push(players[0].address);
            await expect(heap.connect(owner).up(players[1].address)).to.be.revertedWithCustomError(
                heap,
                `HeapValueNotFound`,
            );
        });
    });

    describe('2.7. Down', async () => {
        async function testDownHeap(vals: number[], queries: [string, number][]) {
            const n_values = vals.length;
            const addresses = players.slice(0, n_values).map(p => p.address);
            const values = new MapWithDefault((_: string) => 0);
            for (let i = 0; i < n_values; ++i) {
                values.set(addresses[i], vals[i]);
                await heap.connect(owner).setValue(addresses[i], vals[i]);
            }

            for (let i = 0; i < n_values; ++i) {
                await heap.connect(owner).push(addresses[i]);
            }

            for (const [address, delta] of queries) {
                values.set(address, values.get(address) - delta);
                await gasCalculator.callTransaction(heap.connect(owner).setValue(address, values.get(address)));
                await gasCalculator.callTransaction(heap.connect(owner).down(address));
                const heap_addresses: string[] = await (heap.allValues());
                expect(checkHeapProperties(heap_addresses, values)).to.equal(true, 'Heap after remove not has heap properties');
            }
        }

        it('2.7.1 Random 200 down heap with value [1, 10000] of 20 addresses', async () => {
            const values = [];
            for (let i = 1; i <= 20; ++i) {
                values.push(1000000000);
            }
            const queries: [string, number][] = [];
            for (let i = 1; i <= 200; ++i) {
                const address = players[rng.range(20)].address;
                const delta = rng.intBetween(1, 10000);
                queries.push([address, delta]);
            }
            await testDownHeap(values, queries);
        });

        it('2.7.2 Random 200 down heap with value [0, 1] of 20 addresses', async () => {
            const values = [];
            for (let i = 1; i <= 20; ++i) {
                values.push(1000000000);
            }
            const queries: [string, number][] = [];
            for (let i = 1; i <= 200; ++i) {
                const address = players[rng.range(20)].address;
                const delta = rng.intBetween(0, 1);
                queries.push([address, delta]);
            }
            await testDownHeap(values, queries);
        });

        it('2.7.3 Revert down heap of address not in heap', async () => {
            await heap.connect(owner).setValue(players[0].address, 5);
            await heap.connect(owner).push(players[0].address);
            await expect(heap.connect(owner).down(players[1].address)).to.be.revertedWithCustomError(
                heap,
                `HeapValueNotFound`,
            );
        });
    });


    describe('2.8. Full flow test', async () => {
        const QueryType = {
            PUSH: 0,
            POP: 1,
            REMOVE: 2,
            UP: 3,
            DOWN: 4,
        };

        async function testFullflow(n_addresses: number, n_query: number, value_range: [number, number]) {
            const values = new MapWithDefault((_: string) => 0);
            let address_in_heap: any[] = [];
            let address_not_in_heap: any[] = players.slice(0, n_addresses).map(p => p.address);

            const add_to_heap = (address: string, val: number) => {
                values.set(address, val + 1000000000);
                address_in_heap.push(address);
                address_not_in_heap = address_not_in_heap.filter(a => a != address);
            }
            const remove_from_heap = (address: string) => {
                values.delete(address);
                address_in_heap = address_in_heap.filter(a => a != address);
                address_not_in_heap.push(address);
            }

            for (let i = 1; i <= n_query; ++i) {
                let type;
                if (address_in_heap.length == 0) {
                    type = 0;
                } else if (address_not_in_heap.length == 0) {
                    type = rng.intBetween(1, 4);
                } else {
                    type = rng.intBetween(0, 4);
                }

                if (type == QueryType.PUSH) {
                    const address = randUtils.sample(address_not_in_heap);
                    const val = rng.intBetween(value_range[0] * 5, value_range[1] * 5);
                    add_to_heap(address, val);
                    await gasCalculator.callTransaction(heap.connect(owner).setValue(address, values.get(address)));
                    await gasCalculator.callTransaction(heap.connect(owner).push(address));
                    // console.log('PUSH', values.get(address));
                } else if (type == QueryType.POP) {
                    const address = await heap.peek();
                    remove_from_heap(address);
                    await gasCalculator.callTransaction(heap.connect(owner).pop());
                } else if (type == QueryType.REMOVE) {
                    const address = randUtils.sample(address_in_heap);
                    remove_from_heap(address);
                    await gasCalculator.callTransaction(heap.connect(owner).remove(address));
                } else if (type == QueryType.UP) {
                    const address = randUtils.sample(address_in_heap);
                    const delta = rng.intBetween(value_range[0], value_range[1]);
                    values.set(address, values.get(address) + delta);
                    await gasCalculator.callTransaction(heap.connect(owner).setValue(address, values.get(address)));
                    await gasCalculator.callTransaction(heap.connect(owner).up(address));
                    // console.log('UP', values.get(address));
                } else if (type == QueryType.DOWN) {
                    const address = randUtils.sample(address_in_heap);
                    const delta = rng.intBetween(value_range[0], value_range[1]);
                    values.set(address, values.get(address) - delta);
                    await gasCalculator.callTransaction(heap.connect(owner).setValue(address, values.get(address)));
                    await gasCalculator.callTransaction(heap.connect(owner).down(address));
                    // console.log('DOWN', values.get(address));
                }

                const heap_addresses: string[] = await (heap.allValues());
                expect(checkHeapProperties(heap_addresses, values)).to.equal(true, 'Heap after query not has heap properties');
                expect(isSameElements(address_in_heap, heap_addresses)).to.equal(true, 'Incorrect heap addresses');
            }

            gasCalculator.reportGas();
        }

        it('2.8.1 Random 1000 operations with value [1, 10000] of 20 addresses', async () => {
            await testFullflow(20, 1000, [1, 10000]);
        });

        it('2.8.2 Random 1000 operations with value [0, 1] of 20 addresses', async () => {
            await testFullflow(20, 1000, [0, 1]);
        });
    });
});