// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Operator.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPairOracle.sol";

contract DndToBtcOracle is Operator, IOracle {
    using SafeMath for uint256;
    address public oracleDndBnb;
    address public chainlinkBnbBtc;
    address public diamond;

    uint256 private constant PRICE_PRECISION = 1e6;

    constructor(
        address _diamond,
        address _oracleDndBnb,
        address _chainlinkBnbBtc
    ) {
        diamond = _diamond;
        chainlinkBnbBtc = _chainlinkBnbBtc;
        oracleDndBnb = _oracleDndBnb;
    }

    function consult() external view override returns (uint256) {
        uint256 _priceBnbBtc = priceBnbBtc();
        uint256 _priceShareBnb = IPairOracle(oracleDndBnb).consult(diamond, PRICE_PRECISION);
        return _priceShareBnb.mul(PRICE_PRECISION).div(_priceBnbBtc);
    }

    function priceBnbBtc() internal view returns (uint256) {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(chainlinkBnbBtc);
        (, int256 _price, , , ) = _priceFeed.latestRoundData();
        uint8 _decimals = _priceFeed.decimals();
        return uint256(_price).mul(PRICE_PRECISION).div(uint256(10)**_decimals);
    }

    function setChainlinkBnbBtc(address _chainlinkBnbBtc) external onlyOperator {
        chainlinkBnbBtc = _chainlinkBnbBtc;
    }

    function setOracleDndBnb(address _oracleDndBnb) external onlyOperator {
        oracleDndBnb = _oracleDndBnb;
    }
}
