// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IDiamond.sol";
import "./interfaces/IDToken.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IPool.sol";
import "./Operator.sol";

contract Pool is Operator, ReentrancyGuard, IPool {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    /* ========== STATE VARIABLES ========== */

    address public override collateral;
    address public override dToken;
    address public override diamond;
    address public oracleDiamond;
    address public oracleDToken;
    address public treasury;

    mapping(address => uint256) public redeem_diamond_balances;
    mapping(address => uint256) public redeem_collateral_balances;

    uint256 public unclaimed_pool_collateral;
    uint256 public unclaimed_pool_diamond;

    mapping(address => uint256) public last_redeemed;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // Number of decimals needed to get to 18
    uint256 private missing_decimals;

    // Pool_ceiling is the total units of collateral that a pool contract can hold
    uint256 public pool_ceiling = 0;

    // Number of blocks to wait before being able to collectRedemption()
    uint256 public redemption_delay = 1;

    // AccessControl state variables
    bool public mint_paused = false;
    bool public redeem_paused = false;
    bool public migrated = false;

    // Collateral ratio
    uint256 public last_refresh_cr_timestamp;
    uint256 public target_collateral_ratio = 1000000;
    uint256 public effective_collateral_ratio = 1000000;
    bool public target_collateral_ratio_paused = false;
    bool public effective_collateral_ratio_paused = false;
    uint256 public refresh_cooldown;
    uint256 public ratio_step;
    uint256 public price_target;
    uint256 public price_band;
    uint256 private constant COLLATERAL_RATIO_PRECISION = 1e6;
    uint256 private constant COLLATERAL_RATIO_MAX = 1e6;

    // fee
    uint256 public redemption_fee;
    uint256 public minting_fee;

    /* ========== MODIFIERS ========== */

    modifier notMigrated() {
        require(!migrated, "migrated");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _dToken,
        address _diamond,
        address _collateral,
        uint256 _pool_ceiling,
        address _treasury
    ) {
        dToken = _dToken;
        diamond = _diamond;
        collateral = _collateral;
        treasury = _treasury;
        pool_ceiling = _pool_ceiling;
        missing_decimals = uint256(18).sub(ERC20(_collateral).decimals());
        ratio_step = 2500;
        target_collateral_ratio = 1000000;
        effective_collateral_ratio = 1000000;
        refresh_cooldown = 3600;
        price_target = 1000000; // match exactly 100%
        price_band = 5000; // 0.5% of diff
        redemption_fee = 3000;
        minting_fee = 2000;
    }

    /* ========== VIEWS ========== */

    function collateralReserve() public view returns (address) {
        return ITreasury(treasury).collateralReserve();
    }

    function collateralBalance() public view returns (uint256) {
        return (ERC20(collateral).balanceOf(collateralReserve()).sub(unclaimed_pool_collateral)).mul(10**missing_decimals);
    }

    function info()
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            address,
            address,
            string memory,
            string memory,
            uint256,
            uint256
        )
    {
        return (pool_ceiling, collateralBalance(), unclaimed_pool_collateral, unclaimed_pool_diamond, minting_fee, redemption_fee, mint_paused, redeem_paused, collateral, dToken, ERC20(collateral).symbol(), ERC20(dToken).symbol(), target_collateral_ratio, effective_collateral_ratio);
    }

    function diamondToCollateralPrice() public view override returns (uint256) {
        return IOracle(oracleDiamond).consult();
    }

    function dTokenToCollateralPrice() public view override returns (uint256) {
        return IOracle(oracleDToken).consult();
    }

    function calcEffectiveCollateralRatio() public view returns (uint256) {
        if (effective_collateral_ratio_paused) {
            return target_collateral_ratio;
        }
        uint256 total_collateral = collateralBalance();
        uint256 total_supply_dToken = IERC20(dToken).totalSupply();
        uint256 ecr = total_collateral.mul(PRICE_PRECISION).div(total_supply_dToken);
        if (ecr > COLLATERAL_RATIO_MAX) {
            return COLLATERAL_RATIO_MAX;
        }
        return ecr;
    }

    function calcCollateralBalance() public view override returns (uint256 _collateral_amount, bool _exceeded) {
        uint256 target_collateral_amount = IERC20(dToken).totalSupply().mul(target_collateral_ratio).div(PRICE_PRECISION);
        uint256 total_collateral_amount = collateralBalance();
        if (total_collateral_amount >= target_collateral_amount) {
            _collateral_amount = total_collateral_amount.sub(target_collateral_amount);
            _exceeded = true;
        } else {
            _collateral_amount = target_collateral_amount.sub(total_collateral_amount);
            _exceeded = false;
        }
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function mint(
        uint256 _collateral_amount,
        uint256 _diamond_amount,
        uint256 _dtoken_out_min
    ) external override notMigrated {
        require(!mint_paused, "Minting is paused");
        require(collateralBalance().add(_collateral_amount) <= pool_ceiling, "Pool ceiling was reached");

        uint256 _diamond_relative_price = diamondToCollateralPrice();
        uint256 _total_value = 0;
        uint256 _required_diamond_amount = 0;
        if (target_collateral_ratio > 0) {
            _total_value = _collateral_amount.mul(COLLATERAL_RATIO_PRECISION).div(target_collateral_ratio);
            if (target_collateral_ratio < COLLATERAL_RATIO_MAX) {
                _required_diamond_amount = _total_value.sub(_collateral_amount).mul(PRICE_PRECISION).div(_diamond_relative_price);
            }
        } else {
            _total_value = _diamond_amount.mul(_diamond_relative_price).div(PRICE_PRECISION);
            _required_diamond_amount = _diamond_amount;
        }
        uint256 _actual_output_amount = _total_value.sub((_total_value.mul(minting_fee)).div(PRICE_PRECISION));
        require(_dtoken_out_min <= _actual_output_amount, ">slippage");

        if (_required_diamond_amount > 0) {
            require(_required_diamond_amount <= _diamond_amount, "<shareBalance");
            IDiamond(diamond).poolBurnFrom(msg.sender, _required_diamond_amount);
        }
        if (_collateral_amount > 0) {
            _transferCollateralToReserve(msg.sender, _collateral_amount);
        }
        IDToken(dToken).poolMint(msg.sender, _actual_output_amount);
    }

    function mintSingle(uint256 _collateral_amount, uint256 _dtoken_out_min) external override notMigrated {
        require(!mint_paused, "Minting is paused");
        require(collateralBalance().add(_collateral_amount) <= pool_ceiling, "Pool ceiling was reached");
        uint256 _collateral_value = _collateral_amount * (10**missing_decimals);
        uint256 _actual_dtoken_amount = _collateral_value.sub((_collateral_value.mul(minting_fee)).div(PRICE_PRECISION));
        require(_dtoken_out_min <= _actual_dtoken_amount, ">slippage");

        if (_collateral_amount > 0) {
            _transferCollateralToReserve(msg.sender, _collateral_amount);
        }
        IDToken(dToken).poolMint(msg.sender, _actual_dtoken_amount);
    }

    function redeem(
        uint256 _dToken_amount,
        uint256 _diamond_out_min,
        uint256 _collateral_out_min
    ) external notMigrated {
        require(!redeem_paused, "Redeeming is paused");
        uint256 _diamond_relative_price = diamondToCollateralPrice();
        uint256 _dtoken_amount_post_fee = _dToken_amount.sub((_dToken_amount.mul(redemption_fee)).div(PRICE_PRECISION));
        uint256 _collateral_output_amount = 0;
        uint256 _diamond_output_amount = 0;

        if (effective_collateral_ratio < COLLATERAL_RATIO_MAX) {
            uint256 _diamond_output_value = _dtoken_amount_post_fee.sub(_dtoken_amount_post_fee.mul(effective_collateral_ratio).div(PRICE_PRECISION));
            _diamond_output_amount = _diamond_output_value.mul(PRICE_PRECISION).div(_diamond_relative_price);
        }

        if (effective_collateral_ratio > 0) {
            _collateral_output_amount = _dtoken_amount_post_fee.div(10**missing_decimals).mul(effective_collateral_ratio).div(PRICE_PRECISION);
        }

        if (_collateral_output_amount > 0) {
            redeem_collateral_balances[msg.sender] = redeem_collateral_balances[msg.sender].add(_collateral_output_amount);
            unclaimed_pool_collateral = unclaimed_pool_collateral.add(_collateral_output_amount);
        }

        if (_diamond_output_amount > 0) {
            redeem_diamond_balances[msg.sender] = redeem_diamond_balances[msg.sender].add(_diamond_output_amount);
            unclaimed_pool_diamond = unclaimed_pool_diamond.add(_diamond_output_amount);
        }

        last_redeemed[msg.sender] = block.number;

        // Check if collateral balance meets and meet output expectation
        require(ERC20(collateral).balanceOf(collateralReserve()) >= unclaimed_pool_collateral, "<collateralBalance");
        require(_collateral_out_min <= _collateral_output_amount && _diamond_out_min <= _diamond_output_amount, ">slippage");

        // Move all external functions to the end
        IDToken(dToken).poolBurnFrom(msg.sender, _dToken_amount);
        if (_diamond_output_amount > 0) {
            _mintDiamondToCollateralReserve(_diamond_output_amount);
        }
    }

    function collectRedemption() external {
        // Redeem and Collect cannot happen in the same transaction to avoid flash loan attack
        require((last_redeemed[msg.sender].add(redemption_delay)) <= block.number, "<redemption_delay");

        bool _send_diamond = false;
        bool _send_collateral = false;
        uint256 _share_amount;
        uint256 _collateral_amount;

        if (redeem_diamond_balances[msg.sender] > 0) {
            _share_amount = redeem_diamond_balances[msg.sender];
            redeem_diamond_balances[msg.sender] = 0;
            unclaimed_pool_diamond = unclaimed_pool_diamond.sub(_share_amount);
            _send_diamond = true;
        }

        if (redeem_collateral_balances[msg.sender] > 0) {
            _collateral_amount = redeem_collateral_balances[msg.sender];
            redeem_collateral_balances[msg.sender] = 0;
            unclaimed_pool_collateral = unclaimed_pool_collateral.sub(_collateral_amount);
            _send_collateral = true;
        }

        if (_send_diamond) {
            _requestTransferDiamond(msg.sender, _share_amount);
        }

        if (_send_collateral) {
            _requestTransferCollateral(msg.sender, _collateral_amount);
        }
    }

    function refreshCollateralRatio() public {
        require(!target_collateral_ratio_paused, "Target Collateral Ratio has been paused");
        require(block.timestamp - last_refresh_cr_timestamp >= refresh_cooldown, "Must wait for the refresh cooldown since last refresh");

        uint256 current_dtoken_price = dTokenToCollateralPrice();

        if (current_dtoken_price > price_target.add(price_band)) {
            if (target_collateral_ratio <= ratio_step) {
                target_collateral_ratio = 0;
            } else {
                target_collateral_ratio = target_collateral_ratio.sub(ratio_step);
            }
        } else if (current_dtoken_price < price_target.sub(price_band)) {
            if (target_collateral_ratio.add(ratio_step) >= COLLATERAL_RATIO_MAX) {
                target_collateral_ratio = COLLATERAL_RATIO_MAX;
            } else {
                target_collateral_ratio = target_collateral_ratio.add(ratio_step);
            }
        }

        // If using ECR, then calcECR. If not, update ECR = TCR
        if (!effective_collateral_ratio_paused) {
            effective_collateral_ratio = calcEffectiveCollateralRatio();
        } else {
            effective_collateral_ratio = target_collateral_ratio;
        }

        last_refresh_cr_timestamp = block.timestamp;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _transferCollateralToReserve(address _sender, uint256 _amount) internal {
        address _reserve = collateralReserve();
        require(_reserve != address(0), "Invalid reserve address");
        ERC20(collateral).safeTransferFrom(_sender, _reserve, _amount);
    }

    function _mintDiamondToCollateralReserve(uint256 _amount) internal {
        address _reserve = collateralReserve();
        require(_reserve != address(0), "Invalid reserve address");
        IDiamond(diamond).poolMint(_reserve, _amount);
    }

    function _requestTransferCollateral(address _receiver, uint256 _amount) internal {
        ITreasury(treasury).requestTransfer(collateral, _receiver, _amount);
    }

    function _requestTransferDiamond(address _receiver, uint256 _amount) internal {
        ITreasury(treasury).requestTransfer(diamond, _receiver, _amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setOracleDToken(address _oracleDToken) public onlyOperator {
        oracleDToken = _oracleDToken;
    }

    function setOracleDiamond(address _oracleDiamond) public onlyOperator {
        oracleDiamond = _oracleDiamond;
    }

    function toggleMinting() external onlyOperator {
        mint_paused = !mint_paused;
    }

    function toggleRedeeming() external onlyOperator {
        redeem_paused = !redeem_paused;
    }

    function setPoolCeiling(uint256 _pool_ceiling) external onlyOperator {
        pool_ceiling = _pool_ceiling;
    }

    function setRedemptionDelay(uint256 _redemption_delay) external onlyOperator {
        redemption_delay = _redemption_delay;
    }

    function setRedemptionFee(uint256 _redemption_fee) public onlyOperator {
        redemption_fee = _redemption_fee;
        emit RedemptionFeeChanged(redemption_fee);
    }

    function setMintingFee(uint256 _minting_fee) public onlyOperator {
        minting_fee = _minting_fee;
        emit MintingFeeChanged(minting_fee);
    }

    function setRatioStep(uint256 _ratio_step) public onlyOperator {
        ratio_step = _ratio_step;
        emit RatioStepChanged(ratio_step);
    }

    function setPriceTarget(uint256 _price_target) public onlyOperator {
        price_target = _price_target;
    }

    function setRefreshCooldown(uint256 _refresh_cooldown) public onlyOperator {
        refresh_cooldown = _refresh_cooldown;
    }

    function setPriceBand(uint256 _price_band) external onlyOperator {
        price_band = _price_band;
        emit PriceBandChanged(price_band);
    }

    function toggleCollateralRatio() public onlyOperator {
        target_collateral_ratio_paused = !target_collateral_ratio_paused;
    }

    function toggleEffectiveCollateralRatio() public onlyOperator {
        effective_collateral_ratio_paused = !effective_collateral_ratio_paused;
    }

    function setDiamondAddress(address _diamond) public onlyOperator {
        diamond = _diamond;
    }

    function setTreasury(address _treasury) public onlyOperator {
        treasury = _treasury;
        emit TreasuryChanged(treasury);
    }

    /* =============== EVENTS ==================== */

    event TreasuryChanged(address indexed newTreasury);
    event PriceBandChanged(uint256 newPriceBand);
    event MintingFeeChanged(uint256 newPriceBand);
    event RedemptionFeeChanged(uint256 newPriceBand);
    event RatioStepChanged(uint256 newPriceBand);
}
