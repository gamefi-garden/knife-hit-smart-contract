import assert from 'assert';
import {ethers, network, upgrades} from 'hardhat';

async function deployAsyncKnifeHit() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const AsyncKnifeHit = await ethers.getContractFactory('AsyncKnifeHit');
    const asyncKnifeHitAddress = config.asyncKnifeHitAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.asyncKnifeHitAddress,
                AsyncKnifeHit,
            )
            console.log(`Contract AsyncKnifeHit has been updated to address ${config.asyncKnifeHitAddress}`);
            return config.asyncKnifeHitAddress;
        })() :
      

        await (async () => {
            const asyncGameHubAddress = config.asyncGameHubAddress;
            // assert.ok(
            //     asyncGameHubAddress,
            //     `Missing ${networkName}_ASYNC_GAME_HUB_ADDRESS from environment variables!`
            // );
            // const asyncGameHubAddress = "a0x2A78894744bEb8D65c9Ae1AaF4cF0a4B88a9C4A3";
            const asyncKnifeHit = await upgrades.deployProxy(
                AsyncKnifeHit
                ,
                [asyncGameHubAddress]
            );

            await asyncKnifeHit.deployed();
            console.log(`Contract AsyncRockScissorsPaper has been deployed to address ${asyncKnifeHit.address}`);
            return asyncKnifeHit.address;
        })();

    console.log(`${networkName}_ASYNC_RSP_ADDRESS=${asyncKnifeHitAddress}`);
}

deployAsyncKnifeHit()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
