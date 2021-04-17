// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "hardhat/console.sol";

pragma solidity 0.7.6;

contract MockValueLiquidRouter {
    using SafeMath for uint256;

    function swapExactTokensForTokens(
        address _input_token,
        address _output_token,
        uint256 _input_amount,
        uint256 _min_output_amount,
        address[] memory path,
        address to,
        uint256
    ) public returns (uint256[] memory amounts) {
        console.log("_input_token %s %s", _input_token, _input_amount);
        console.log("_output_token %s", _output_token);
        IERC20(_input_token).transferFrom(to, address(this), _input_amount);

        amounts = new uint256[](path.length);
        amounts[0] = _input_amount;
        amounts[1] = _min_output_amount.mul(1001).div(1000);
        // IERC20(_output_token).transfer(to, _min_output_amount.mul(1001).div(1000));
    }
}
