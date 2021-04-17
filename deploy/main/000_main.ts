import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import chalk from 'chalk';
import {skipTags} from '../../utils/network';

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

  const treasury = await deploy('Treasury', {
    ...defaultConfig,
    args: [],
  });

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
    startTime
  ).catch((e) => {
    console.log('already init');
  });
};

func.tags = ['bsctest', 'init'];
skipTags(func);
export default func;
