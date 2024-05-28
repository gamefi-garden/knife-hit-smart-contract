import {BigNumber, ContractTransaction, ContractReceipt, BytesLike, Wallet} from "ethers";

export class Game {
    address: string;
    name: string;
    defaultTicketPrice: BigNumber;
    defaultAdditionalDuration: number;
    defaultFeePercentage: number;
    wallet: Wallet;

    constructor(obj: {
        address: string,
        name: string,
        defaultTicketPrice: BigNumber,
        defaultAdditionalDuration: number,
        defaultFeePercentage: number,
        wallet: Wallet,
    }) {
        this.address = obj.address;
        this.name = obj.name;
        this.defaultTicketPrice = obj.defaultTicketPrice;
        this.defaultAdditionalDuration = obj.defaultAdditionalDuration;
        this.defaultFeePercentage = obj.defaultFeePercentage;
        this.wallet = obj.wallet;
    }

    toArray(): [string, string, BigNumber, number, number] {
        return [this.address, this.name, this.defaultTicketPrice, this.defaultAdditionalDuration, this.defaultFeePercentage];
    }
}

export class CreatePotParams {
    alpha: string;
    gameAddress: string;
    ticketPrice: BigNumber;
    feePercentage: number;
    initialDuration: number;
    additionalDuration: number;
    initialValue: BigNumber;
    balanceRequirement: BigNumber;
    rewardConfigId: number;

    constructor(obj: {
        alpha: string,
        gameAddress: string,
        ticketPrice: BigNumber,
        feePercentage: number,
        initialDuration: number,
        additionalDuration: number,
        initialValue: BigNumber,
        balanceRequirement: BigNumber,
        rewardConfigId: number,
    }) {
        this.alpha = obj.alpha;
        this.gameAddress = obj.gameAddress;
        this.ticketPrice = obj.ticketPrice;
        this.feePercentage = obj.feePercentage;
        this.initialDuration = obj.initialDuration;
        this.additionalDuration = obj.additionalDuration;
        this.initialValue = obj.initialValue;
        this.balanceRequirement = obj.balanceRequirement;
        this.rewardConfigId = obj.rewardConfigId;
    }

    toArray(): [string, string, BigNumber, number, number, number, BigNumber, BigNumber, number] {
        return [
            this.alpha,
            this.gameAddress,
            this.ticketPrice,
            this.feePercentage,
            this.initialDuration,
            this.additionalDuration,
            this.initialValue,
            this.balanceRequirement,
            this.rewardConfigId,
        ];
    }
}

export class CreatePotWithSignatureParams {
    creator: string;
    alpha: string;
    gameAddress: string;
    ticketPrice: BigNumber;
    feePercentage: number;
    initialDuration: number;
    additionalDuration: number;
    initialValue: BigNumber;
    balanceRequirement: BigNumber;
    rewardConfigId: number;
    signature: BytesLike;

    constructor(obj: {
        creator: string,
        alpha: string,
        gameAddress: string,
        ticketPrice: BigNumber,
        feePercentage: number,
        initialDuration: number,
        additionalDuration: number,
        initialValue: BigNumber,
        balanceRequirement: BigNumber,
        rewardConfigId: number,
        signature: BytesLike,
    }) {
        this.creator = obj.creator;
        this.alpha = obj.alpha;
        this.gameAddress = obj.gameAddress;
        this.ticketPrice = obj.ticketPrice;
        this.feePercentage = obj.feePercentage;
        this.initialDuration = obj.initialDuration;
        this.additionalDuration = obj.additionalDuration;
        this.initialValue = obj.initialValue;
        this.balanceRequirement = obj.balanceRequirement;
        this.rewardConfigId = obj.rewardConfigId;
        this.signature = obj.signature;
    }

    toArray(): [string, string, string, BigNumber, number, number, number, BigNumber, BigNumber, number, BytesLike] {
        return [
            this.creator,
            this.alpha,
            this.gameAddress,
            this.ticketPrice,
            this.feePercentage,
            this.initialDuration,
            this.additionalDuration,
            this.initialValue,
            this.balanceRequirement,
            this.rewardConfigId,
            this.signature,
        ];
    }
}
