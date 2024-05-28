import * as hardhat from "hardhat";
import * as assert from "assert";

const {network} = hardhat;

async function main() {
    const networkConfig = network.config as any;

    assert.ok(networkConfig.jackpotAddress, "Missing TournamentGameHub.sol.sol contract address from environment variables!");

    try {
        await hardhat.run('verify:verify', {
            address: networkConfig.jackpotAddress,
            contract: 'contracts/TournamentGameHub.sol.sol:TournamentGameHub.sol.sol',
        })
    } catch (e: any) {
        console.error(e.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
