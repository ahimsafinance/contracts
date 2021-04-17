import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {skipTags} from '../../utils/network';
import assert from 'assert';

const VswapPairs = {
  'diamond-collateral': '',
  'dToken-collateral': '',
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  assert(
    VswapPairs['diamond-collateral'] && VswapPairs['dToken-collateral'],
    'Invalid config'
  );
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {creator} = await getNamedAccounts();
  const defaultConfig = {from: creator, log: true};

  const PairOracle_DIAMOND_ETH = await deploy('PairOracle_DIAMOND_ETH', {
    contract: 'VSwapPairOracle',
    ...defaultConfig,
    args: [VswapPairs['diamond-collateral']],
  });

  const PairOracle_dETH_ETH = await deploy('PairOracle_dETH_ETH', {
    contract: 'VSwapPairOracle',
    ...defaultConfig,
    args: [VswapPairs['dToken-collateral']],
  });

  await execute(
    'PoolETH',
    defaultConfig,
    'setOracleDToken',
    PairOracle_dETH_ETH.address
  );

  await execute(
    'PoolETH',
    defaultConfig,
    'setOracleDiamond',
    PairOracle_DIAMOND_ETH.address
  );

  await deployments.execute('PairOracle_DETH_ETH', defaultConfig, 'update');

  await deployments.execute('PairOracle_DIAMOND_ETH', defaultConfig, 'update');
};

func.tags = ['bsctest', 'oracles'];
skipTags(func);
export default func;
