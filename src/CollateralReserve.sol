// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/ICollateralReserve.sol";
import "./Operator.sol";

contract CollateralReserve is Operator, ICollateralReserve {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // CONTRACTS
    address public treasury;

    /* ========== MODIFIER ========== */

    modifier onlyTreasury() {
        require(treasury == msg.sender, "Only treasury can trigger this function");
        _;
    }

    /* ========== VIEWS ================ */

    function fundBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function transferTo(
        address _token,
        address _receiver,
        uint256 _amount
    ) public override onlyTreasury {
        require(_receiver != address(0), "Invalid address");
        require(_amount > 0, "Cannot transfer zero amount");
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function setTreasury(address _treasury) external onlyOperator {
        treasury = _treasury;
        emit TreasuryChanged(treasury);
    }

    event TreasuryChanged(address indexed newTreasury);
}
