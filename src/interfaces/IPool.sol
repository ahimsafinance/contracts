// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface IPool {
    function diamond() external view returns (address);

    function dToken() external view returns (address);

    function collateral() external view returns (address);

    function calcCollateralBalance() external view returns (uint256 _collateral_value, bool _exceeded);

    function diamondToCollateralPrice() external view returns (uint256);

    function dTokenToCollateralPrice() external view returns (uint256);

    function info()
        external
        view
        returns (
            uint256 pool_ceiling,
            uint256 collateral_balance,
            uint256 unclaimed_pool_collateral,
            uint256 unclaimed_pool_diamond,
            uint256 minting_fee,
            uint256 redemption_fee,
            bool mint_paused,
            bool redeem_paused,
            address _collateral,
            address d_token,
            string memory collateral_symbol,
            string memory d_token_symbol,
            uint256 target_collateral_ratio,
            uint256 effective_collateral_ratio
        );

    function mint(
        uint256 _collateral_amount,
        uint256 _diamond_amount,
        uint256 _dtoken_out_min
    ) external;

    function mintSingle(uint256 _collateral_amount, uint256 _dtoken_out_min) external;
}
