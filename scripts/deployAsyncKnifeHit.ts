import assert from 'assert';
import {ethers, network, upgrades} from 'hardhat';

async function deployAsyncRsp() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const AsyncRsp = await ethers.getContractFactory('AsyncRockScissorsPaper');
    const asyncRspAddress = config.asyncRspAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.asyncRspAddress,
                AsyncRsp,
            )
            console.log(`Contract AsyncRockScissorsPaper has been updated to address ${config.asyncRspAddress}`);
            return config.asyncRspAddress;
        })() :
        await (async () => {
            const asyncGameHubAddress = config.asyncGameHubAddress;
            assert.ok(
                asyncGameHubAddress,
                `Missing ${networkName}_ASYNC_GAME_HUB_ADDRESS from environment variables!`
            );

            const asyncRsp = await upgrades.deployProxy(
                AsyncRsp,
                [asyncGameHubAddress]
            );

            await asyncRsp.deployed();
            console.log(`Contract AsyncRockScissorsPaper has been deployed to address ${asyncRsp.address}`);
            return asyncRsp.address;
        })();

    console.log(`${networkName}_ASYNC_RSP_ADDRESS=${asyncRspAddress}`);
}

deployAsyncRsp()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
