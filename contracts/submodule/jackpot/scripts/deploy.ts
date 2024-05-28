import {ethers, network, upgrades} from 'hardhat';
import * as fs from "fs";
import * as assert from "assert";

async function deploy() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const tokenAddress = config.tokenAddress;
    assert.ok(
        tokenAddress,
        `Missing ${networkName}_TOKEN_ADDRESS from environment variables!`
    );

    const alphaKeysFactoryAddress = config.alphaKeysFactoryAddress;
    assert.ok(
        alphaKeysFactoryAddress,
        `Missing ${networkName}_ALPHA_KEYS_FACTORY_ADDRESS from environment variables!`
    );

    const treasuryAddress = config.treasuryAddress;
    assert.ok(
        alphaKeysFactoryAddress,
        `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
    );

    const operationFundAddress = config.operationFundAddress;
    assert.ok(
        alphaKeysFactoryAddress,
        `Missing ${networkName}_OPERATION_FUND_ADDRESS from environment variables!`
    );

    const operationFundPercentage = 10;
    const reservePercentage = 20;
    const rewardPortions = [
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
    ];

    const Jackpot = await ethers.getContractFactory('JackpotGameHub');
    const jackpotAddress = config.jackpotAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.jackpotAddress,
                Jackpot,
            )
            console.log(`Contract JackpotGameHub has been updated to address ${config.jackpotAddress}`);
            return config.jackpotAddress;
        })() :
        await (async () => {
            const jackpot = await upgrades.deployProxy(
                Jackpot,
                [
                    tokenAddress,
                    alphaKeysFactoryAddress,
                    treasuryAddress,
                    operationFundAddress,
                    operationFundPercentage,
                    reservePercentage,
                    rewardPortions,
                ],
            )
            await jackpot.deployed();
            console.log(`Contract JackpotGameHub has been deployed to address ${jackpot.address}`);
            return jackpot.address;
        })();

    console.log(`${networkName}_TOKEN_ADDRESS=${tokenAddress}`);
    console.log(`${networkName}_ALPHA_KEY_FACOTORY_ADDRESS=${alphaKeysFactoryAddress}`);
    console.log(`${networkName}_TREASURY_ADDRESS=${treasuryAddress}`);
    console.log(`${networkName}_OPERATION_FUND_ADDRESS=${operationFundAddress}`);
    console.log(`${networkName}_JACKPOT_ADDRESS=${jackpotAddress}`);

    fs.writeFileSync(
        "contract_addresses.json",
        JSON.stringify({
            alphaKeysFactoryAddress,
            treasuryAddress,
            operationFundAddress,
            jackpotAddress
        } as any, null, 2)
    );
}

deploy()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
