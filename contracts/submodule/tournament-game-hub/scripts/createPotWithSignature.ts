import {ethers, network} from "hardhat";
import assert from "assert";

async function createPotWithSignature() {
    const config = network.config as any;
    const networkName = network.name.toUpperCase();

    const gameHubAddress = config.gameHubAddress;
    assert.ok(
        gameHubAddress,
        `Missing ${networkName}_GAME_HUB_ADDRESS from environment variables!`
    );

    const tokenAddress = config.tokenAddress;
    assert.ok(
        tokenAddress,
        `Missing ${networkName}_TOKEN_ADDRESS from environment variables!`
    );

    const creatorPrivateKey = process.env.CREATE_POT_CREATOR_PRIVATE_KEY;

    const alpha = process.env.CREATE_POT_ALPHA;
    assert.ok(
        alpha,
        `Missing CREATE_POT_ALPHA from environment variables!`
    );

    const gameAddress = process.env.CREATE_POT_GAME_ADDRESS;
    assert.ok(
        gameAddress,
        `Missing CREATE_POT_GAME_ADDRESS from environment variables!`
    );

    const ticketPrice = process.env.CREATE_POT_TICKET_PRICE;
    assert.ok(
        ticketPrice,
        `Missing CREATE_POT_TICKET_PRICE from environment variables!`
    );

    const feePercentage = process.env.CREATE_POT_FEE_PERCENTAGE;
    assert.ok(
        feePercentage,
        `Missing CREATE_POT_FEE_PERCENTAGE from environment variables!`
    );

    const initialDuration = process.env.CREATE_POT_INITIAL_DURATION;
    assert.ok(
        initialDuration,
        `Missing CREATE_POT_INITIAL_DURATION from environment variables!`
    );

    const additionalDuration = process.env.CREATE_POT_ADDITIONAL_DURATION;
    assert.ok(
        additionalDuration,
        `Missing CREATE_POT_ADDITIONAL_DURATION from environment variables!`
    );

    const initialValue = process.env.CREATE_POT_INITIAL_VALUE;
    assert.ok(
        initialValue,
        `Missing CREATE_POT_INITIAL_VALUE from environment variables!`
    );

    const balanceRequirement = process.env.CREATE_POT_BALANCE_REQUIREMENT;
    assert.ok(
        balanceRequirement,
        `Missing CREATE_POT_BALANCE_REQUIREMENT from environment variables!`
    );

    const rewardConfigId = process.env.CREATE_POT_REWARD_CONFIG_ID;
    assert.ok(
        rewardConfigId,
        `Missing CREATE_POT_REWARD_CONFIG_ID from environment variables!`
    );

    const creator = creatorPrivateKey ?
        new ethers.Wallet(creatorPrivateKey, ethers.provider) :
        (await ethers.getSigners())[0];

    const TournamentGameHub = await ethers.getContractFactory('TournamentGameHub');
    const gameHub = TournamentGameHub.attach(gameHubAddress);
    const token = await ethers.getContractAt('IERC20Upgradeable', tokenAddress, creator);

    await (await token.approve(gameHubAddress, initialValue)).wait();

    const nonce = await gameHub.nonces(creator.address);

    const messageHash = ethers.utils.arrayify(ethers.utils.solidityKeccak256(
        [
            'address',
            'uint256',
            'address',
            'address',
            'uint256',
            'uint40',
            'uint256',
            'uint256',
            'uint32'
        ],
        [
            gameHubAddress,
            nonce,
            alpha,
            gameAddress,
            ticketPrice,
            initialDuration,
            initialValue,
            balanceRequirement,
            rewardConfigId
        ]
    ));
    const signature = ethers.utils.arrayify(await creator.signMessage(messageHash));

    await (await gameHub.createPotWithSignature(
        creator.address,
        alpha,
        gameAddress,
        ticketPrice,
        feePercentage,
        initialValue,
        additionalDuration,
        initialValue,
        balanceRequirement,
        rewardConfigId,
        signature
    )).wait()
}

createPotWithSignature()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });