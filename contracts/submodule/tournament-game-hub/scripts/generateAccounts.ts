import {ethers} from "hardhat";
import * as fs from "fs";
import assert from "assert";

const ADDRESS_NUMBER = 20;

async function generateAccounts() {
    const privateKeyPrefix = process.env.SECRET_PRIVATE_KEY_PREFIX;
    assert.ok(
        privateKeyPrefix,
        `Missing SECRET_PRIVATE_KEY_PREFIX from environment variables!`
    );

    const accounts = [];
    for (let i = 0; i < ADDRESS_NUMBER; ++i) {
        const wallet = new ethers.Wallet(
            ethers.utils.id(privateKeyPrefix + i),
            ethers.provider,
        );

        accounts.push({
            secret: privateKeyPrefix + i,
            privateKey: wallet.privateKey,
            address: wallet.address,
        });
    }

    console.log(accounts);
    fs.writeFileSync(
        'addresses.json',
        JSON.stringify(
            {addresses: accounts.map(account => account.address)},
            null,
            2
        )
    );
}

generateAccounts()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });