import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import chalk from 'chalk';
import {skipTags} from '../utils/network';

const VswapPairs = {
  'dnd-bnb': '0xf95af1a0a40f24436b2368974dc09a9c5cd51be7',
  'dbtc-btc': '0xf0877464837842eb393abf81bb8e0abd4a929b01',
  'dbnb-bnb': '0x240282a1bb4d3a76c6250e2b1e1c2e1b1841c18e',
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  console.log(chalk.yellow('004 :: set oracle address'));
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {creator} = await getNamedAccounts();

  // const PairOracle_DND_BNB = await deploy('PairOracle_DND_BNB', {
  //   contract: 'VSwapPairOracle',
  //   from: creator,
  //   log: true,
  //   args: [VswapPairs['dnd-bnb'], '0xf6C5241F7ee009ebc3fA88ec7Aec7402d86BCBE0'],
  // });

  // const PairOracle_dBTC_BTC = await deploy('PairOracle_dBTC_BTC', {
  //   contract: 'VSwapPairOracle',
  //   from: creator,
  //   log: true,
  //   args: [
  //     VswapPairs['dbtc-btc'],
  //     '0x02974fCEca338C36e874AEE05Cb0278f8A190b8a',
  //   ],
  // });

  // const PairOracle_dBNB_BNB = await deploy('PairOracle_dBNB_BNB', {
  //   contract: 'VSwapPairOracle',
  //   from: creator,
  //   log: true,
  //   args: [
  //     VswapPairs['dbnb-bnb'],
  //     '0x2745c5fd2c8c9E123d2a7DD66e93E557A2353b5f',
  //   ],
  // });

  // const MockChainlink_BTC_BNB = await deploy('MockChainlink_BTC_BNB', {
  //   contract: 'MockChainlinkAggregator',
  //   from: creator,
  //   log: true,
  //   args: ['143554388935574620000', 18],
  // });

  // const DndToBnbOracle = await deploy('DndToBnbOracle', {
  //   contract: 'DndToBnbOracle',
  //   from: creator,
  //   log: true,
  //   args: [
  //     '0xf6C5241F7ee009ebc3fA88ec7Aec7402d86BCBE0',
  //     PairOracle_DND_BNB.address,
  //   ],
  // });

  // const DndToBtcOracle = await deploy('DndToBtcOracle', {
  //   contract: 'DndToBtcOracle',
  //   from: creator,
  //   log: true,
  //   args: [
  //     '0xf6C5241F7ee009ebc3fA88ec7Aec7402d86BCBE0',
  //     PairOracle_DND_BNB.address,
  //     MockChainlink_BTC_BNB.address,
  //   ],
  // });

  // const dBtcToBtcOracle = await deploy('DBtcToBtcOracle', {
  //   contract: 'DBtcToBtcOracle',
  //   from: creator,
  //   log: true,
  //   args: [
  //     '0x2745c5fd2c8c9E123d2a7DD66e93E557A2353b5f',
  //     PairOracle_dBTC_BTC.address,
  //   ],
  // });

  // const dBnbToBnbOracle = await deploy('DBnbToBnbOracle', {
  //   contract: 'DBnbToBnbOracle',
  //   from: creator,
  //   log: true,
  //   args: [
  //     '0x2745c5fd2c8c9E123d2a7DD66e93E557A2353b5f',
  //     PairOracle_dBNB_BNB.address,
  //   ],
  // });

  const dBnbToBnbVPegOracle = await deploy('VPegOracleBnb', {
    contract: 'VPegOracle',
    from: creator,
    log: true,
    args: [],
  });

  const dBtcToBtcVPegOracle = await deploy('VPegOracleBtc', {
    contract: 'VPegOracle',
    from: creator,
    log: true,
    args: [],
  });

  // await execute(
  //   'PoolBTC',
  //   {
  //     from: creator,
  //     log: true,
  //   },
  //   'setOracleDToken',
  //   dBtcToBtcOracle.address
  // );

  // await execute(
  //   'PoolBTC',
  //   {
  //     from: creator,
  //     log: true,
  //   },
  //   'setOracleDiamond',
  //   DndToBtcOracle.address
  // );

  // await execute(
  //   'poolBNB',
  //   {
  //     from: creator,
  //     log: true,
  //   },
  //   'setOracleDToken',
  //   dBnbToBnbOracle.address
  // );

  // await execute(
  //   'poolBNB',
  //   {
  //     from: creator,
  //     log: true,
  //   },
  //   'setOracleDiamond',
  //   DndToBnbOracle.address
  // );
};

func.tags = ['bsctest', 'oracle', 'bsctest_phase2'];
skipTags(func);
export default func;
