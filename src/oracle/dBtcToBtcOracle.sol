// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Operator.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPairOracle.sol";

contract DBtcToBtcOracle is Operator, IOracle {
    using SafeMath for uint256;
    address public oraclePairDBtcBtc;
    address public dBTC;
    uint256 private constant PRICE_PRECISION = 1e6;

    constructor(address _dBTC, address _oraclePairDBtcBtc) {
        dBTC = _dBTC;
        oraclePairDBtcBtc = _oraclePairDBtcBtc;
    }

    function consult() external view override returns (uint256) {
        return IPairOracle(oraclePairDBtcBtc).twap(PRICE_PRECISION);
    }

    function setOraclePairDBtcBtc(address _oraclePairDBtcBtc) external onlyOperator {
        oraclePairDBtcBtc = _oraclePairDBtcBtc;
    }
}
