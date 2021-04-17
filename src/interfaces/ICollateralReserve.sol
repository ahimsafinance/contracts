// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface ICollateralReserve {
    function transferTo(
        address _token,
        address _receiver,
        uint256 _amount
    ) external;
}
