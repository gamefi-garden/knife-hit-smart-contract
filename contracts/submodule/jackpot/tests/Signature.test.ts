import {ethers, upgrades} from "hardhat";
import {expect} from "chai";
import {
    TestSignature,
    TestSignature__factory,
} from "../typechain-types";

let Signature: TestSignature__factory, signature: TestSignature;
let owner: any, users: any[];

describe('4. Signature', async () => {
    before(async () => {
        Signature = await ethers.getContractFactory('TestSignature');
    });

    beforeEach(async () => {
        signature = await upgrades.deployProxy(Signature) as TestSignature;
        await signature.deployed();

        [owner] = await ethers.getSigners();

        users = [];
        for (let i = 0; i < 2; ++i) {
            users.push(new ethers.Wallet(
                ethers.utils.id(i.toString()),
                ethers.provider
            ));
        }
    });

    describe('4.1. verifyEthSignature', async () => {
        it('4.1.1 Verify correct signature', async () => {
            const wallet = new ethers.Wallet(
                ethers.utils.id("1"),
                ethers.provider);

            const message = "Test Message";
            const messageHash = ethers.utils.id(message);
            const messageHashBytes = ethers.utils.arrayify(messageHash);
            const sig = await wallet.signMessage(messageHashBytes);
            const sigBytes = ethers.utils.arrayify(sig);

            // console.log("address:", wallet.address);
            // console.log("message:", message);
            // console.log("messageHash:", messageHash);
            // console.log("messageHashBytes:", messageHashBytes);
            // console.log("sig:", sig);
            // console.log("sigBytes:", sigBytes);
            // console.log("------------------------")

            const verifyResult = await signature.verifyEthSignature(wallet.address, messageHashBytes, sigBytes);
            expect(verifyResult).to.equal(true, "Correct signature is verified as incorrect");
        });

        it('4.1.2 Not verify incorrect signature (author diff)', async () => {
            const wallet1 = new ethers.Wallet(
                ethers.utils.id("1"),
                ethers.provider);
            const wallet2 = new ethers.Wallet(
                ethers.utils.id("2"),
                ethers.provider);

            const message = "Test Message";
            const messageHash = ethers.utils.id(message);
            const messageHashBytes = ethers.utils.arrayify(messageHash);
            const sig = await wallet1.signMessage(messageHashBytes);
            const sigBytes = ethers.utils.arrayify(sig);

            const verifyResult = await signature.verifyEthSignature(wallet2.address, messageHashBytes, sigBytes);
            expect(verifyResult).to.equal(false, "Incorrect author signature is verified as incorrect");
        });

        it('4.1.3 Not verify incorrect signature (message diff)', async () => {
            const wallet = new ethers.Wallet(
                ethers.utils.id("1"),
                ethers.provider);

            const message = "Test Message";
            const messageHash = ethers.utils.id(message);
            const messageHashBytes = ethers.utils.arrayify(messageHash);
            const sig = await wallet.signMessage(messageHashBytes);
            const sigBytes = ethers.utils.arrayify(sig);

            const message2 = "Test Message 2";
            const messageHash2 = ethers.utils.id(message2);
            const messageHashBytes2 = ethers.utils.arrayify(messageHash2);

            const verifyResult = await signature.verifyEthSignature(wallet.address, messageHashBytes2, sigBytes);
            expect(verifyResult).to.equal(false, "Incorrect message signature is verified as incorrect");
        });
    });
});