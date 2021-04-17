// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Operator.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPairOracle.sol";

contract DBnbToBnbOracle is Operator, IOracle {
    using SafeMath for uint256;
    address public oracleDBnbToBnb;
    address public dBNB;

    uint256 private constant PRICE_PRECISION = 1e6;

    constructor(address _dBNB, address _oracleDBnbToBnb) {
        dBNB = _dBNB;
        oracleDBnbToBnb = _oracleDBnbToBnb;
    }

    function consult() external view override returns (uint256) {
        uint256 _priceDBnb = IPairOracle(oracleDBnbToBnb).twap(PRICE_PRECISION);
        return _priceDBnb;
    }

    function setOracleDBnbToBnb(address _oracleDBnbToBnb) external onlyOperator {
        oracleDBnbToBnb = _oracleDBnbToBnb;
    }
}
