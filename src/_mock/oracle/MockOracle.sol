// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IOracle.sol";
import "../../Operator.sol";

contract MockOracle is IOracle, Operator {
    using SafeMath for uint256;

    uint256 public mockPrice;
    uint256 public constant PRICE_PRECISION = 1e6;
    uint256 public PERIOD = 3600; // 1 hour TWAP (time-weighted average price)

    constructor(uint256 _mockPrice) {
        mockPrice = _mockPrice;
    }

    function consult() external view override returns (uint256 amountOut) {
        return mockPrice;
    }

    function setPeriod(uint256 _period) external onlyOperator {
        PERIOD = _period;
    }

    function mock(uint256 _mockPrice) external {
        mockPrice = _mockPrice;
    }
}
