import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import chalk from 'chalk';
import {skipTags} from '../utils/network';
import {Numbers} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {deployer, creator, devFund, timelock_admin} = await getNamedAccounts();
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
    devFund,
    devFund,
    devFund,
    startTime
  ).catch(() => {
    console.log('already init');
  });

  console.log(chalk.yellow('DETECT LOCAL ENV: MOCK COLLATERAL ====='));
  const btc = await deploy('MockBTC', {
    contract: 'MockCollateral',
    from: creator,
    args: ['Binance-Peg Ethereum Token', 'BTC', 18],
    log: true,
  });
  const bnb = await deploy('MockBNB', {
    contract: 'MockCollateral',
    from: creator,
    args: ['Binance Coint', 'BNB', 18],
    log: true,
  });

  console.log(chalk.yellow('003 :: Deploying Pools'));

  // POOL BTC

  const dBTC = await deploy('dBTC', {
    contract: 'DToken',
    from: deployer,
    args: ['Diamond-Peg BTC', 'dBTC', treasury.address],
    log: true,
  });

  await execute('dBTC', defaultConfig, 'initialize', Numbers.ONE_DEC18).catch(
    () => {
      console.log('already init');
    }
  );

  const poolBTC = await deploy('PoolBTC', {
    contract: 'Pool',
    ...defaultConfig,
    args: [
      dBTC.address,
      diamond.address,
      btc.address,
      Numbers.ONE_DEC18.mul(10000),
      treasury.address,
    ],
  });

  await execute('Treasury', defaultConfig, 'addPool', poolBTC.address).catch(
    () => {
      console.log('Pool added before');
    }
  );

  console.log(chalk.yellow('Deploy foundry'));
  const foundryBTC = await deploy('FoundryBTC', {
    contract: 'Foundry',
    ...defaultConfig,
  });

  await execute(
    'FoundryBTC',
    defaultConfig,
    'initialize',
    btc.address,
    diamond.address,
    treasury.address
  ).catch((e) => {
    console.log('inited');
  });

  await execute(
    'Treasury',
    defaultConfig,
    'addFoundry',
    foundryBTC.address,
    poolBTC.address
  );

  console.log('setUtilizationRatio');
  await execute(
    'Treasury',
    defaultConfig,
    'setUtilizationRatio',
    poolBTC.address,
    3000
  );

  // POOL BTC

  const dBNB = await deploy('dBNB', {
    contract: 'DToken',
    from: deployer,
    args: ['Diamond-Peg BNB', 'dBNB', treasury.address],
    log: true,
  });

  await execute(
    'dBNB',
    defaultConfig,
    'initialize',
    Numbers.ONE_DEC18.mul(100)
  ).catch(() => {
    console.log('already init');
  });

  const poolBNB = await deploy('poolBNB', {
    contract: 'Pool',
    ...defaultConfig,
    args: [
      dBNB.address,
      diamond.address,
      bnb.address,
      Numbers.ONE_MILLION_DEC18,
      treasury.address,
    ],
  });

  await execute('Treasury', defaultConfig, 'addPool', poolBNB.address).catch(
    () => {
      console.log('Pool added before');
    }
  );

  console.log(chalk.yellow('Deploy foundry'));
  const foundryBNB = await deploy('FoundryBNB', {
    contract: 'Foundry',
    ...defaultConfig,
  });

  await execute(
    'FoundryBNB',
    defaultConfig,
    'initialize',
    bnb.address,
    diamond.address,
    treasury.address
  ).catch((e) => {
    console.log('inited');
  });

  await execute(
    'Treasury',
    defaultConfig,
    'addFoundry',
    foundryBNB.address,
    poolBNB.address
  );

  console.log('setUtilizationRatio');
  await execute(
    'Treasury',
    defaultConfig,
    'setUtilizationRatio',
    poolBNB.address,
    3000
  );

  // Init treasury
  // await execute('Treasury', defaultConfig, 'setEpochDuration', 30 * 60 * 60);
};

func.tags = ['bsctest', 'main', 'bsctest_phase1'];
skipTags(func);
export default func;
