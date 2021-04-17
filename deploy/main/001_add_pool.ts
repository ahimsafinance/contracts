import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import chalk from 'chalk';
import {skipTags} from '../../utils/network';
import {Numbers} from '../../utils/constants';
import assert from 'assert';

const DToken = {
  name: '',
  symbol: '',
};

const collateralAddress = '';
const excessCollateralDistributedRatio = 5000;

const dTokenDeployment = `dToken_${DToken.symbol}`;
const poolDeployment = `Pool_${DToken.symbol}`;
const foundryDeployment = `Foundry_${DToken.symbol}`;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  assert(
    DToken.name &&
      DToken.symbol &&
      collateralAddress &&
      excessCollateralDistributedRatio,
    'Invalid configuration'
  );
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute, get} = deployments;
  const {deployer, creator} = await getNamedAccounts();
  const defaultConfig = {from: creator, log: true};

  const diamond = await get('Diamond');
  const treasury = await get('Treasury');

  const dToken = await deploy(dTokenDeployment, {
    contract: 'DToken',
    from: deployer,
    args: [DToken.name, DToken.symbol],
    log: true,
  });

  await execute(dTokenDeployment, defaultConfig, 'initialize');

  console.log(chalk.yellow('003 :: Deploying Pools'));

  const poolETH = await deploy(poolDeployment, {
    contract: 'Pool',
    ...defaultConfig,
    args: [
      dToken.address,
      diamond.address,
      collateralAddress,
      Numbers.ONE_HUNDRED_MILLION_DEC18,
    ],
  });

  await execute('Treasury', defaultConfig, 'addPool', poolETH.address);
  await execute(dTokenDeployment, defaultConfig, 'setPool', poolETH.address);
  await execute(
    poolDeployment,
    {from: creator},
    'setTreasury',
    treasury.address
  );

  console.log(chalk.yellow('Deploy foundry'));
  const foundry = await deploy(foundryDeployment, {
    contract: 'Foundry',
    ...defaultConfig,
  });

  await execute(
    foundryDeployment,
    defaultConfig,
    'initialize',
    collateralAddress,
    diamond.address,
    treasury.address
  );

  await execute(
    'Treasury',
    defaultConfig,
    'addFoundry',
    foundry.address,
    poolETH.address
  );

  await execute(
    'Treasury',
    defaultConfig,
    'setExcessCollateralDistributedRatio',
    poolETH.address,
    excessCollateralDistributedRatio
  );
};

func.tags = ['bsctest', 'pool'];
skipTags(func);
export default func;
