import {ethers, network, upgrades} from 'hardhat';
import * as fs from "fs";
import assert from "assert";

async function deployTournamentGameHub() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const tokenAddress = config.tokenAddress;
    assert.ok(
        tokenAddress,
        `Missing ${networkName}_TOKEN_ADDRESS from environment variables!`
    );

    const treasuryAddress = config.treasuryAddress;
    assert.ok(
        treasuryAddress,
        `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
    );

    const alphaKeysFactoryAddress = config.alphaKeysFactoryAddress;
    assert.ok(
        alphaKeysFactoryAddress,
        `Missing ${networkName}_ALPHA_KEYS_FACTORY_ADDRESS from environment variables!`
    );

    const gameLibraryAddress = config.gameLibraryAddress;
    assert.ok(
        gameLibraryAddress,
        `Missing ${networkName}_GAME_LIBRARY_ADDRESS from environment variables!`
    );

    const defaultBalanceRequirement = 1;
    const alphaFeePercentage = 10;
    const rewardPortions = [10000];
    // const rewardPortions = [
    //     8000,   // 80%
    //     800,    // 8%
    //     100,    // 1%
    //     100,    // 1%
    //     100,    // 1%
    //     100,    // 1%
    //     100,    // 1%
    //     100,    // 1%
    //     100,    // 1%
    //     100,    // 1%
    //     50,     // 0.5%
    //     50,     // 0.5%
    //     50,     // 0.5%
    //     50,     // 0.5%
    //     50,     // 0.5%
    //     50,     // 0.5%
    //     25,     // 0.25%
    //     25,     // 0.25%
    //     25,     // 0.25%
    //     25,     // 0.25%
    // ];
    const moderators = JSON.parse(fs.readFileSync('addresses.json').toString()).addresses;

    const TournamentGameHub = await ethers.getContractFactory('TournamentGameHub');
    const gameHubAddress = config.gameHubAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.gameHubAddress,
                TournamentGameHub,
            )
            console.log(`Contract TournamentGameHub has been updated to address ${config.gameHubAddress}`);
            return config.gameHubAddress;
        })() :
        await (async () => {
            const gameHub = await upgrades.deployProxy(
                TournamentGameHub,
                [
                    tokenAddress,
                    treasuryAddress,
                    gameLibraryAddress,
                    alphaKeysFactoryAddress,
                    alphaFeePercentage,
                    defaultBalanceRequirement,
                    rewardPortions,
                    moderators
                ],
            )
            await gameHub.deployed();
            console.log(`Contract TournamentGameHub has been deployed to address ${gameHub.address}`);
            return gameHub.address;
        })();

    console.log(`${networkName}_TOKEN_ADDRESS=${tokenAddress}`);
    console.log(`${networkName}_TREASURY_ADDRESS=${treasuryAddress}`);
    console.log(`${networkName}_GAME_LIBRARY_ADDRESS=${gameLibraryAddress}`);
    console.log(`${networkName}_ALPHA_KEYS_FACTORY_ADDRESS=${alphaKeysFactoryAddress}`);
    console.log(`${networkName}_GAME_HUB_ADDRESS=${gameHubAddress}`);

    fs.writeFileSync(
        "contract_addresses.json",
        JSON.stringify({
            tokenAddress,
            treasuryAddress,
            gameLibraryAddress,
            alphaKeysFactoryAddress,
            tournamentGameHubAddress: gameHubAddress
        } as any, null, 2)
    );
}

deployTournamentGameHub()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
