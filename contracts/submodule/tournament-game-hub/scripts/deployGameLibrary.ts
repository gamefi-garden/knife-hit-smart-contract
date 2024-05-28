import {ethers, network, upgrades} from 'hardhat';

async function deployGameLibrary() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const GameLibrary = await ethers.getContractFactory('GameLibrary');
    const gameLibraryAddress = config.gameLibraryAddress ?
        await (async () => {
            await upgrades.upgradeProxy(
                config.gameLibraryAddress,
                GameLibrary,
            )
            console.log(`Contract GameLibrary has been updated to address ${config.gameLibraryAddress}`);
            return config.gameLibraryAddress;
        })() :
        await (async () => {
            const gameLibrary = await upgrades.deployProxy(GameLibrary)
            await gameLibrary.deployed();
            console.log(`Contract GameLibrary has been deployed to address ${gameLibrary.address}`);
            return gameLibrary.address;
        })();

    console.log(`${networkName}_GAME_LIBRARY_ADDRESS=${gameLibraryAddress}`);
}

deployGameLibrary()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
