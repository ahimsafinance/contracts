// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/ISwap.sol";
import "../libs/FixedPoint.sol";
import "../libs/UQ112x112.sol";
import "../Operator.sol";
import "../interfaces/IPairOracle.sol";

// fixed window oracle that recomputes the average price for the entire epochPeriod once every epochPeriod
// note that the price average is only guaranteed to be over at least 1 epochPeriod, but may be over a longer epochPeriod
// @dev This version 2 supports querying twap with shorted period (ie 2hrs for BSDB reference price)
contract VPegOracle is Operator, IPairOracle {
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
    uint256 public lastUpdateHour;
    uint256 public updatePeriod;

    // BPool
    address public mainToken;
    uint256 public mainTokenDecimal;
    uint8 public mainTokenIndex;
    uint8 public sideTokenIndex;
    uint256 public sideTokenDecimal;
    ISwap public pool;

    // Pool price for update in cumulative epochPeriod
    uint32 public blockTimestampCumulativeLast;
    uint256 public priceCumulative;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public priceCumulativeLast;
    FixedPoint.uq112x112 public priceAverage;

    bool private _initialized = false;

    uint256 private constant swapFee = 20000000;
    uint256 private constant FEE_DENOMINATOR = 10**10;

    event Updated(uint256 priceCumulativeLast);

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _pool,
        address _mainToken,
        address _sideToken,
        uint256 _epoch,
        uint256 _epochPeriod,
        uint256 _updatePeriod
    ) public {
        require(_initialized == false, "OracleVPeg: Initialize must be false.");

        mainToken = _mainToken;
        mainTokenDecimal = ERC20(_mainToken).decimals();
        {
            pool = ISwap(_pool);

            uint8 _mainTokenIndex = pool.getTokenIndex(_mainToken);
            uint8 _sideTokenIndex = pool.getTokenIndex(_sideToken);
            require(pool.getTokenBalance(_mainTokenIndex) != 0 && pool.getTokenBalance(_sideTokenIndex) != 0, "OracleVPeg: NO_RESERVES"); // ensure that there's liquidity in the pool

            mainTokenIndex = _mainTokenIndex;
            sideTokenIndex = _sideTokenIndex;
            sideTokenDecimal = ERC20(_sideToken).decimals();
        }

        epoch = _epoch;
        epochPeriod = _epochPeriod;
        updatePeriod = _updatePeriod;
        _initialized = true;
    }

    /* ========== GOVERNANCE ========== */

    function setEpoch(uint256 _epoch) external onlyOperator {
        epoch = _epoch;
    }

    function setEpochPeriod(uint256 _epochPeriod) external onlyOperator {
        require(_epochPeriod >= 1 hours && _epochPeriod <= 48 hours, "_epochPeriod out of range");
        epochPeriod = _epochPeriod;
    }

    function setLastUpdateHour(uint256 _lastUpdateHour) external onlyOperator {
        lastUpdateHour = _lastUpdateHour;
    }

    function setUpdatePeriod(uint256 _updatePeriod) external onlyOperator {
        require(_updatePeriod >= 1 hours && _updatePeriod <= epochPeriod, "_updatePeriod out of range");
        updatePeriod = _updatePeriod;
    }

    function setOneAmountTokenMain(uint256 _oneAmountTokenMain) external onlyOperator {
        oneAmountTokenMain = _oneAmountTokenMain;
    }

    function setMaxEpochPeriod(uint256 _maxEpochPeriod) external onlyOperator {
        require(_maxEpochPeriod <= 48 hours, "_maxEpochPeriod is not valid");
        maxEpochPeriod = _maxEpochPeriod;
    }

    function setPool(address _pool, address _sideToken) public onlyOperator {
        pool = ISwap(_pool);

        uint8 _mainTokenIndex = pool.getTokenIndex(mainToken);
        uint8 _sideTokenIndex = pool.getTokenIndex(_sideToken);

        require(pool.getTokenBalance(_mainTokenIndex) != 0 && pool.getTokenBalance(_sideTokenIndex) != 0, "OracleVPeg: NO_RESERVES"); // ensure that there's liquidity in the pool

        mainTokenIndex = _mainTokenIndex;
        sideTokenIndex = _sideTokenIndex;
        sideTokenDecimal = ERC20(_sideToken).decimals();
    }

    /* ========== VIEW FUNCTIONS ========== */

    function nextEpochPoint() public view returns (uint256) {
        return lastEpochTime.add(epochPeriod);
    }

    function nextUpdateHour() public view returns (uint256) {
        return lastUpdateHour.add(updatePeriod);
    }

    /* ========== MUTABLE FUNCTIONS ========== */
    // update reserves and, on the first call per block, price accumulators
    function updateCumulative() public {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // Overflow is desired

        // Ensure that at least one full period has passed since the last update
        require(timeElapsed >= updatePeriod, "OracleVPeg: PERIOD_NOT_ELAPSED");

        uint256 _decimalFactor = 10**(mainTokenDecimal.sub(sideTokenDecimal));
        uint256 tokenMainPricePostFee = pool.calculateSwap(mainTokenIndex, sideTokenIndex, oneAmountTokenMain).mul(_decimalFactor);
        uint256 tokenMainPrice = tokenMainPricePostFee.mul(FEE_DENOMINATOR).div(FEE_DENOMINATOR.sub(swapFee));
        require(tokenMainPrice != 0, "!price");
        require(tokenMainPrice <= uint112(-1), "OracleVPeg: overflow");

        priceCumulative += uint256(UQ112x112.encode(uint112(tokenMainPrice)).uqdiv(uint112(oneAmountTokenMain))) * timeElapsed;
        blockTimestampCumulativeLast = blockTimestamp;
    }

    function update() external override {
        updateCumulative();
        uint32 timeElapsed = blockTimestampCumulativeLast - blockTimestampLast; // overflow is desired
        require(timeElapsed >= epochPeriod, "OracleVPeg: epoch too short");
        priceAverage = FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast) / timeElapsed));
        priceCumulativeLast = priceCumulative;
        blockTimestampLast = blockTimestampCumulativeLast;
        emit Updated(priceCumulative);
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn) external view override returns (uint256 amountOut) {
        require(token == mainToken, "OracleVPeg: INVALID_TOKEN");
        require(block.timestamp.sub(blockTimestampLast) <= maxEpochPeriod, "OracleVPeg: Price out-of-date");
        amountOut = priceAverage.mul(amountIn).decode144();
    }

    function twap(uint256 _amountIn) external view override returns (uint256) {
        uint32 timeElapsed = blockTimestampCumulativeLast - blockTimestampLast;
        return (timeElapsed == 0) ? priceAverage.mul(_amountIn).decode144() : FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast) / timeElapsed)).mul(_amountIn).decode144();
    }
}
