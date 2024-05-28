import {BigNumber, ContractReceipt, ContractTransaction, BaseContract, ContractFactory, Wallet} from "ethers";
import {expect} from "chai";
import Random from "random-seed";
import {ethers} from "hardhat";
import * as assert from "assert";

export async function callTransaction(transaction: Promise<ContractTransaction>): Promise<ContractReceipt> {
    return await (await transaction).wait();
}

export async function expectViewToBeRevertedWithCustomError(
    func: Promise<any>,
    contract: BaseContract | ContractFactory,
    customErrorName: string
): Promise<void> {
    if (Object.values(contract.interface.errors).filter(error => error.name == customErrorName).length == 0) {
        throw Error(`The given contract doesn't have a custom error named '${customErrorName}'`);
    }

    let passed = false;
    try {
        await func;
        passed = true;
    } catch (error: any) {
        try {
            const errorData = error.error.data;
            const errorName = contract.interface.parseError(errorData).name;
            console.log(errorData);
            console.log(errorName);
            assert.equal(errorName, customErrorName);
        } catch {
            throw Error(`Transaction failed with unexpected reason (${error.toString()})`);
        }
    }

    if (passed) {
        throw Error(`Expected transaction to be reverted with custom error '${customErrorName}', but it didn't revert`)
    }
}

export function verifyContractData(contractData: any, data: any, objName: string) {
    for (const key in data) {
        if (Object.prototype.hasOwnProperty.call(data, key)) {
            expect(contractData[key]).to.equal(data[key], `Incorrect ${objName}'s ${key}`);
        }
    }
}

export async function signMessage(wallet: Wallet, abi_types: string[], values: any[]) {
    const packed = ethers.utils.solidityPack(abi_types, values);
    const messageHash = ethers.utils.keccak256(packed);
    const messageHashBytes = ethers.utils.arrayify(messageHash);
    const sig = await wallet.signMessage(messageHashBytes);
    const sigBytes = ethers.utils.arrayify(sig);
    return sigBytes
}

export class GasCalculator {
    private totalGas: BigNumber;
    private maxGasConsumed: BigNumber;
    private minGasConsumed: BigNumber;
    private transactionCount: number;
    constructor() {
        this.totalGas = BigNumber.from(0);
        this.maxGasConsumed = BigNumber.from(0);
        this.minGasConsumed = ethers.BigNumber.from(ethers.constants.MaxUint256)
        this.transactionCount = 0;    
    }

    reset() {
        this.totalGas = BigNumber.from(0);
        this.maxGasConsumed = BigNumber.from(0);
        this.minGasConsumed = ethers.BigNumber.from(ethers.constants.MaxUint256)
        this.transactionCount = 0;        
    }

    async callTransaction(transaction: Promise<ContractTransaction>): Promise<ContractReceipt> {
        const receipt = await (await transaction).wait();
        const gasConsumed = receipt.gasUsed;

        this.totalGas = this.totalGas.add(gasConsumed);

        if (gasConsumed.gt(this.maxGasConsumed)) {
            this.maxGasConsumed = gasConsumed;
        }

        if (gasConsumed.lt(this.minGasConsumed)) {
            this.minGasConsumed = gasConsumed;
        }

        this.transactionCount++;

        return receipt;
    }

    reportGas() {
        console.log(`Total gas consumed: ${this.totalGas.toString()}`);
        console.log(`Average gas consumed: ${this.totalGas.div(this.transactionCount).toString()}`);
        console.log(`Max gas consumed: ${this.maxGasConsumed.toString()}`);
        console.log(`Min gas consumed: ${this.minGasConsumed.toString()}`)
    }
}

export class RandomUtils {
    rng: Random.RandomSeed;
    
    constructor(rng: Random.RandomSeed) {
        this.rng = rng;
    }

    shuffle(arr: any[]) {
        for (let i = 1; i < arr.length; ++i) {
            let j = this.rng.range(i);
            let tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
    }
    
    sample(arr: any[]) {
        return arr[this.rng.range(arr.length)];
    }
}

export function isSameElements(arr1: any[], arr2: any[]) {
    if (arr1.length != arr2.length) return false;
    const sorted_arr1 = [...arr1].sort();
    const sorted_arr2 = [...arr2].sort();
    for(let i = 0; i < arr1.length; ++i) {
        if (sorted_arr1[i] != sorted_arr2[i]) return false;
    }
    return true;
}

export function isEqualBigNumberArray(arr1: BigNumber[], arr2: BigNumber[]) {    
    if (arr1.length != arr2.length) return false;
    for(let i = 0; i < arr1.length; ++i) {
        if (!arr1[i].eq(arr2[i])) return false;
    }
    return true;
}

export function isEqualArray(arr1: any[], arr2: any[]) {    
    if (arr1.length != arr2.length) return false;
    for(let i = 0; i < arr1.length; ++i) {
        if (arr1[i] !== arr2[i]) return false;
    }
    return true;
}
