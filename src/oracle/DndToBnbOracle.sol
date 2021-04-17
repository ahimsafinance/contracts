// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Operator.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPairOracle.sol";

contract DndToBnbOracle is Operator, IOracle {
    using SafeMath for uint256;
    address public oracleDndBnb;
    address public diamond;

    uint256 private constant PRICE_PRECISION = 1e6;

    constructor(address _diamond, address _oracleDndBnb) {
        diamond = _diamond;
        oracleDndBnb = _oracleDndBnb;
    }

    function consult() external view override returns (uint256) {
        return IPairOracle(oracleDndBnb).consult(diamond, PRICE_PRECISION);
    }

    function setOracleDndBnb(address _oracleDndBnb) external onlyOperator {
        oracleDndBnb = _oracleDndBnb;
    }
}
