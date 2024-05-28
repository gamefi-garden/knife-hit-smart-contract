import assert from 'assert';
import {ethers, network, upgrades} from 'hardhat';
import { Wallet } from "zksync-ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

import * as hre from "hardhat";

async function main() {
    // const config = network.config as any;
    // const networkName = network.name.toUpperCase();
	// const wallet = new Wallet(config.deployerKey);
    // const deployer = new Deployer(hre, wallet);


    // const knifeHit = await ethers.getContractFactory('AsyncKnifeHit');
    // const knifeHit = await ethers.getContractFactory('AsyncKnifeHit');

    // const asyncKnifeHitAddress = config.mainAddress ?
    //     await (async () => {
    //         await upgrades.upgradeProxy(config.mainAddress, knifeHit);
      
    //         return config.mainAddress;
    //       })()
    //       : await (async () => {
    //           const treasuryAddress = config.treasuryAddress;
    //           console.log(`treasuryAddress ${treasuryAddress}`);

    //           assert.ok(
    //               treasuryAddress,
    //               `Missing ${networkName}_TREASURY_ADDRESS from environment variables!`
    //           );
              
    //         let feePercentage = 20;
    //         const poker = await upgrades.deployProxy(knifeHit, [
    //             treasuryAddress,feePercentage]);
                
    //         await poker.deployed();
    //         console.log(`Knife Hit contract is deployed to ${poker.address}`);
    //         return poker.address;
    //     })();

    //     const contract =  knifeHit.attach(asyncKnifeHitAddress);

	
    const networkName = network.name.toUpperCase();
	const networkConfig = network.config as any;

	const gameHubAddress = networkConfig.asyncGameHubAddress;

	const wallet = new Wallet(networkConfig.deployerKey);

	// Create deployer object and load the artifact of the contract you want to deploy.
	const deployer = new Deployer(hre, wallet);
	const KnifeHit = await deployer.loadArtifact(networkConfig.contractFactory);
	const contractAddress = networkConfig.knifeHitAddress
		? await (async () => {
				await hre.zkUpgrades.upgradeProxy(
					deployer.zkWallet,
					networkConfig.knifeHitAddress,
					KnifeHit,
					[],
					{ initializer: "initialize" });
				console.log(
					`KnifeHit contract is upgraded to ${networkConfig.knifeHitAddress}`
				);
				return networkConfig.knifeHitAddress;
		  })()
		: await (async () => {
				const knifeHit =await hre.zkUpgrades.deployProxy(
					deployer.zkWallet,
					KnifeHit,
					[],
					{ initializer: "initialize" });

				await knifeHit.waitForDeployment();
				knifeHit.connect(deployer.zkWallet);
				await knifeHit.updateAsyncGameHubAddress(networkConfig.asyncGameHubAddress);
				console.log(`knifeHit contract is deployed to ${await knifeHit.getAddress()}`);
				return  await knifeHit.getAddress();
		  })();
	console.log(`${networkName}_KNIFEHIT_ADDRESS=${contractAddress}`);


}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
