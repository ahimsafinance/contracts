import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import chalk from 'chalk';
import {skipTags} from '../utils/network';
import {Numbers} from '../utils/constants';

const deployPool = async (
  hre: HardhatRuntimeEnvironment,
  {
    dTokenName,
    dTokenSymbol,
    collateralName,
    collateralSymbol,
    foundryUtilizationRatio,
  }: {
    dTokenName: string;
    dTokenSymbol: string;
    collateralName: string;
    collateralSymbol: string;
    foundryUtilizationRatio: number;
  }
) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute, get} = deployments;
  const {deployer, creator} = await getNamedAccounts();
  const defaultConfig = {from: creator, log: true};
  const diamond = await get('Diamond');
  const treasury = await get('Treasury');
  const poolName = `Pool_${dTokenSymbol}`;
  const oracles = {
    dToken_collateral: `PairOracle_${dTokenSymbol}_${collateralSymbol}`,
    diamond_collateral: `PairOracle_DND_${collateralSymbol}`,
  };
  const foundryName = `Foundry_${dTokenSymbol}`;

  const dToken = await deploy(dTokenSymbol, {
    contract: 'DToken',
    from: deployer,
    args: [dTokenName, dTokenSymbol, treasury.address],
    log: true,
  });

  await execute(dTokenSymbol, defaultConfig, 'initialize').catch((e) => {
    console.log('already init');
  });

  console.log(chalk.yellow('DETECT LOCAL ENV: MOCK COLLATERAL ====='));
  const collateral = await deploy(`Mock${collateralSymbol}`, {
    contract: 'MockCollateral',
    from: creator,
    args: [collateralName, collateralSymbol, 18],
    log: true,
  });

  console.log(chalk.yellow('003 :: Deploying Pools'));

  const pool = await deploy(poolName, {
    contract: 'Pool',
    ...defaultConfig,
    args: [
      dToken.address,
      diamond.address,
      collateral.address,
      Numbers.ONE_HUNDRED_MILLION_DEC18,
      treasury.address,
    ],
  });

  await execute('Treasury', defaultConfig, 'addPool', pool.address).catch(
    () => {
      console.log('Pool added before');
    }
  );

  await execute(dTokenSymbol, defaultConfig, 'setPool', pool.address).catch(
    () => {
      console.log('Pool added before');
    }
  );

  await execute(poolName, {from: creator}, 'setTreasury', treasury.address);

  console.log(chalk.yellow('=== Mock Value Oracle =========='));
  const oracleDTokenCollateral = await deploy(oracles.dToken_collateral, {
    contract: 'MockOracle',
    args: [1005999],
    ...defaultConfig,
  });
  const oracleDiamondCollateral = await deploy(oracles.diamond_collateral, {
    contract: 'MockOracle',
    args: [2000000],
    ...defaultConfig,
  });

  await execute(
    poolName,
    defaultConfig,
    'setOracleDToken',
    oracleDTokenCollateral.address
  );

  await execute(
    poolName,
    defaultConfig,
    'setOracleDiamond',
    oracleDiamondCollateral.address
  );

  console.log(chalk.yellow('Deploy foundry'));
  const foundry = await deploy(foundryName, {
    contract: 'Foundry',
    ...defaultConfig,
  });

  await execute(
    foundryName,
    defaultConfig,
    'initialize',
    collateral.address,
    diamond.address,
    treasury.address
  ).catch((e) => {
    console.log('inited');
  });

  await execute(
    'Treasury',
    defaultConfig,
    'addFoundry',
    foundry.address,
    pool.address
  );

  await execute(
    'Treasury',
    defaultConfig,
    'setUtilizationRatio',
    pool.address,
    foundryUtilizationRatio
  );
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {deployer, creator, timelock_admin} = await getNamedAccounts();
  const defaultConfig = {from: creator, log: true};

  console.log(chalk.yellowBright('001 :: Deploying main contracts'));

  await deploy('Timelock', {
    ...defaultConfig,
    args: [timelock_admin, 12 * 60 * 60], // 6 minutes
  });

  const reserve = await deploy('CollateralReserve', {
    ...defaultConfig,
    args: [],
  });

  const treasury = await deploy('Treasury', {
    ...defaultConfig,
    args: [reserve.address],
  });

  await execute(
    'CollateralReserve',
    defaultConfig,
    'setTreasury',
    treasury.address
  );

  const diamond = await deploy('Diamond', {
    from: deployer,
    args: ['DIAMOND', 'DND', treasury.address],
    log: true,
  });

  const startTime = Math.floor(Date.now() / 1000);
  await execute(
    'Diamond',
    defaultConfig,
    'initialize',
    deployer,
    deployer,
    deployer,
    startTime
  ).catch((e) => {
    console.log('already init');
  });

  await deploy('CollateralReserve', {
    ...defaultConfig,
    args: [],
  });

  await execute(
    'CollateralReserve',
    defaultConfig,
    'setTreasury',
    treasury.address
  );

  const pools = [
    {
      dTokenName: 'Diamond-Peg Bitcoin',
      dTokenSymbol: 'dBTC',
      collateralName: 'Binance-Peg Bitcoin Token',
      collateralSymbol: 'BTCB',
      foundryUtilizationRatio: 2000,
    },
    {
      dTokenName: 'Diamond-Peg BNB',
      dTokenSymbol: 'dBNB',
      collateralName: 'Wrapped BNB',
      collateralSymbol: 'BNB',
      foundryUtilizationRatio: 3000,
    },
  ];

  for (const pool of pools) {
    await deployPool(hre, pool);
  }

  await execute(
    'Treasury',
    defaultConfig,
    'initializeEpoch',
    Math.floor(Date.now() / 1000) + 100,
    15 * 60
  ).catch((e) => {
    console.log('epoch started');
  });

  await deploy('Test', {
    ...defaultConfig,
  });

  // === Mock chainlink feed for BE ===
  await deploy('ChainlinkAggregrator_BNB_USD', {
    ...defaultConfig,
    contract: 'MockChainlinkAggregrator',
    args: [36856280312],
  });

  await deploy('ChainlinkAggregrator_BTCB_USD', {
    ...defaultConfig,
    contract: 'MockChainlinkAggregrator',
    args: [5870448198071],
  });

  await deploy('Multicall', {
    ...defaultConfig,
  });
};

func.tags = ['localhost'];
skipTags(func);
export default func;
