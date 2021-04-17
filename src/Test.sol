// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./libs/FixedPoint.sol";
import "./libs/UQ112x112.sol";
import "./Operator.sol";

// fixed window oracle that recomputes the average price for the entire epochPeriod once every epochPeriod
// note that the price average is only guaranteed to be over at least 1 epochPeriod, but may be over a longer epochPeriod
// @dev This version 2 supports querying twap with shorted period (ie 2hrs for BSDB reference price)
contract Test is Operator {
    using FixedPoint for *;
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public oneAmountTokenMain = 10**18;

    /* ========== STATE VARIABLES ========== */

    // epoch
    uint256 public lastEpochTime;
    uint256 public epoch; // for display only
    uint256 public epochPeriod;
    uint256 public maxEpochPeriod = 1 days;

    // 2-hours update
    uint256 public lastUpdateHour = 0;
    uint256 public updatePeriod = 0;

    mapping(uint256 => uint112) public epochPrice;

    // BPool
    address public mainToken;
    uint256 public mainTokenDecimal = 18;
    uint8 public mainTokenIndex;
    uint8 public sideTokenIndex;
    uint256 public sideTokenDecimal = 18;

    // Pool price for update in cumulative epochPeriod
    uint32 public blockTimestampCumulativeLast;
    uint256 public priceCumulative;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public priceCumulativeLast;
    FixedPoint.uq112x112 public priceAverage;

    bool private _initialized = false;

    event Updated(uint256 priceCumulativeLast);

    /* ========== MUTABLE FUNCTIONS ========== */
    // update reserves and, on the first call per block, price accumulators
    function updateCumulative() public {
        uint256 _updatePeriod = updatePeriod;
        uint256 _nextUpdateHour = lastUpdateHour.add(_updatePeriod);
        if (block.timestamp >= _nextUpdateHour) {
            uint256 tokenMainPrice;

            {
                uint256 _decimalFactor = 10**(mainTokenDecimal.sub(sideTokenDecimal));
                tokenMainPrice = 996834505451885795;
                require(tokenMainPrice != 0, "!price");
                require(tokenMainPrice <= uint112(-1), "OracleVPeg: overflow");
            }

            uint32 blockTimestamp = uint32(block.timestamp % 2**32);
            uint32 timeElapsed = blockTimestamp - blockTimestampCumulativeLast; // overflow is desired

            if (timeElapsed > 0) {
                // * never overflows, and + overflow is desired
                priceCumulative += uint256(UQ112x112.encode(uint112(tokenMainPrice)).uqdiv(uint112(oneAmountTokenMain))) * timeElapsed;

                blockTimestampCumulativeLast = blockTimestamp;
            }

            if (block.timestamp < _nextUpdateHour.add(_updatePeriod)) {
                lastUpdateHour = _nextUpdateHour;
            } else {
                _nextUpdateHour = _nextUpdateHour.add(_updatePeriod);
            }
        }
    }
}
