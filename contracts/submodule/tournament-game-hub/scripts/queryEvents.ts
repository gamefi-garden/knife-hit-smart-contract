import { BigNumber } from 'ethers';
import * as fs from 'fs';
import * as hardhat from "hardhat";

const { ethers, network } = hardhat;
const { provider } = ethers;

class Player {
  winCount: number;
  totalEarning: BigNumber;

  constructor() {
    this.winCount = 0;
    this.totalEarning = BigNumber.from(0);
  }
}

const players: { [address: string]: Player } = {}

async function main() {
  const currentTimestamp = Date.now() / 1000 | 0;
  const endBlock = await provider.getBlockNumber();

  // find start block
  // const queryDuration = 1 * 3600; // 24 hours
  // const startTimestamp = currentTimestamp - queryDuration;
  // const startTimestamp =
  // let l = 0, r = endBlock;
  // let startBlock = endBlock;
  // while (l <= r) {
  //     const mid = (l + r) / 2 | 0;
  //     const blockTimestamp = (await provider.getBlock(mid)).timestamp;
  //     if (blockTimestamp > startTimestamp) {
  //         startBlock = mid;
  //         r = mid - 1;
  //     } else l = mid + 1;
  // }
  let startBlock = 5254062;

  console.log(`Start block number:        \t${startBlock}\t(timestamp: ${(await provider.getBlock(startBlock)).timestamp})`);
  console.log(`End block number:          \t${  endBlock}\t(timestamp: ${(await provider.getBlock(  endBlock)).timestamp})`);

  const Tournament = await ethers.getContractFactory('TournamentGameHub');
  const tournament = Tournament.attach((network.config as any).gameHubAddress);

  const creationFilter = tournament.filters.PotCreation();
  const closureFilter = tournament.filters.PotClosure();

  const creationEvents = await tournament.queryFilter(creationFilter, startBlock, endBlock);
  const closureEvents = await tournament.queryFilter(closureFilter, startBlock, endBlock);

  console.log(`===============================================`);
  console.log(`Scanning PotCreation events:`);
  let potLogs = '';
  for (const event of creationEvents) {
    const pot = await tournament.pots(event.args.potId);
    potLogs += `${event.args.potId},${event.args.creator},${event.args.alpha},${ethers.utils.formatEther(pot.value)},${pot.submissionCount}\n`;
    console.log(`Scanned pot #${event.args.potId}`);
  }
  fs.writeFileSync('tournament_pot_logs.csv', potLogs);

  console.log(`===============================================`);
  console.log(`Scanning PotClosure events:`);
  for (const event of closureEvents) {
    const [, , [winner], [reward]] = await tournament.getPotDistributions(event.args.potId);
    if (winner == undefined) continue;
    if (players[winner] == undefined) {
      players[winner] = new Player();
    }
    players[winner].winCount++;
    players[winner].totalEarning = players[winner].totalEarning.add(reward);
    console.log(`Scanned pot #${event.args.potId}`);
  }

  let playerLogs = '';
  for (const [address, player] of Object.entries(players)) {
    playerLogs += `${address}, ${player.winCount}, ${ethers.utils.formatEther(player.totalEarning)}\n`;
  }
  fs.writeFileSync('tournament_player_logs.csv', playerLogs);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });