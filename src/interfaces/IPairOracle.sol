// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface IPairOracle {
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut);

    function twap(uint256 amountIn) external view returns (uint256 amountOut);

    function update() external;
}
