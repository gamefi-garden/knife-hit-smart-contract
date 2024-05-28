import {BigNumber, ContractReceipt, ContractTransaction} from "ethers";
import Random from "random-seed";
import {ethers} from "hardhat";

export async function callTransaction(transaction: Promise<ContractTransaction>): Promise<ContractReceipt> {
    return await (await transaction).wait();
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

export function isEqualArray(arr1: any[], arr2: any[]) {
    if (arr1.length != arr2.length) return false;
    for(let i = 0; i < arr1.length; ++i) {
        if (arr1[i] != arr2[i]) return false;
    }
    return true;
}