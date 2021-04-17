import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import chalk from 'chalk';
import {skipTags} from '../utils/network';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {creator} = await getNamedAccounts();
  const defaultConfig = {from: creator, log: true};

  console.log(chalk.yellowBright('001 :: Deploying Multicall'));

  await deploy('Multicall', {
    ...defaultConfig,
    args: [],
  });
};

func.tags = ['bsctest', 'main', 'bsctest_multicall'];
skipTags(func);
export default func;
