import assert from 'assert';
import {ethers, network, upgrades} from 'hardhat';

async function deployAsyncKnifeHit() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    // const knifeHit = await ethers.getContractFactory('AsyncKnifeHit');
    const knifeHit = await ethers.getContractFactory('AsyncKnifeHit');

    const asyncKnifeHitAddress = config.mainAddress ?
        await (async () => {
            await upgrades.upgradeProxy(config.mainAddress, knifeHit);
      
            return config.mainAddress;
          })()
          : await (async () => {
              const treasuryAddress = config.treasuryAddress;
              console.log(treasuryAddress);

              assert.ok(
                  treasuryAddress,
                  `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
              );
              
            let maxPlayer = 10;
            let maxChip = 10000
            let smallBlind = 100;
            let bigBlind = 200;
            const poker = await upgrades.deployProxy(knifeHit, [
                treasuryAddress]);
            await poker.deployed();
            console.log(`Knife Hit contract is deployed to ${poker.address}`);
            return poker.address;
        })();

        const contract =  knifeHit.attach(asyncKnifeHitAddress);


}

deployAsyncKnifeHit()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
