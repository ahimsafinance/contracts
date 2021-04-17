// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/ITreasury.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IFoundry.sol";
import "./interfaces/ICollateralReserve.sol";
import "./Operator.sol";

contract Treasury is Operator, ITreasury, ReentrancyGuard {
    using SafeMath for uint256;

    // pools
    address[] public pools_array;
    mapping(address => bool) public pools;
    mapping(address => address) public foundries; // map pool => foundry
    mapping(address => address) public pool_by_foundry; // map pool => foundry

    // addresses
    address public override collateralReserve;

    // mines
    uint256 public override epoch;
    uint256 public epochLength;
    uint256 public lastEpochTimestamp;
    mapping(address => uint256) public utilizationRatiosMapping;
    bool public epochInitialized;
    uint256 public epochStartTime;

    // constants
    uint256 public constant RATIO_PRECISION = 1e6;
    uint256 public constant UTILIZATION_RATION_MAX = 50000; // cannot be larger than 5%

    /* ========== MODIFIERS ========== */

    modifier checkEpoch {
        uint256 _nextEpochPoint = nextEpochTimestamp();
        require(block.timestamp >= _nextEpochPoint, "Treasury: not opened yet");
        _;
        lastEpochTimestamp = _nextEpochPoint;
        epoch = epoch.add(1);
    }

    modifier onlyPools {
        require(isPool(msg.sender), "Only pools can use this function");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(address _collateralReserve) {
        collateralReserve = _collateralReserve;
    }

    /* ========== VIEWS ========== */

    function isPool(address _address) public view override returns (bool) {
        return pools[_address];
    }

    function isMintingPool(address _poolAddress, address _dToken) public view override returns (bool) {
        bool existed = isPool(_poolAddress);
        if (!existed) {
            return false;
        }
        address poolDToken = IPool(_poolAddress).dToken();
        if (poolDToken != _dToken) {
            return false;
        }
        return true;
    }

    function utilizationRatio(address _foundry) external view override returns (uint256) {
        address _pool = pool_by_foundry[_foundry];
        return utilizationRatiosMapping[_pool];
    }

    function nextEpochTimestamp() public view override returns (uint256) {
        return lastEpochTimestamp.add(epochLength);
    }

    function epochInfo()
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (epoch, nextEpochTimestamp(), epochLength);
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function allocateSeigniorage() external nonReentrant checkEpoch {
        for (uint256 index = 0; index < pools_array.length; index++) {
            if (pools_array[index] == address(0)) continue;
            allocateSeigniorageForPool(pools_array[index]);
        }
    }

    /* -========= INTERNAL FUNCTIONS ============ */

    function allocateSeigniorageForPool(address _poolAddress) internal {
        address foundry = foundries[_poolAddress];

        if (foundry == address(0)) {
            return;
        }

        IPool pool = IPool(_poolAddress);
        (uint256 _excess_collateral_amount, bool _exceeded) = pool.calcCollateralBalance();
        if (!_exceeded) {
            return;
        }

        address poolCollateral = pool.collateral();
        uint256 poolUtilizationRatio = utilizationRatiosMapping[_poolAddress];
        uint256 _allocation_amount = _excess_collateral_amount.mul(poolUtilizationRatio).div(RATIO_PRECISION);
        if (_allocation_amount > 0) {
            IFoundry(foundry).allocateSeigniorage(_allocation_amount);
            ICollateralReserve(collateralReserve).transferTo(poolCollateral, foundry, _allocation_amount);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function requestTransfer(
        address _token,
        address _receiver,
        uint256 _amount
    ) external override onlyPools {
        ICollateralReserve(collateralReserve).transferTo(_token, _receiver, _amount);
    }

    function initializeEpoch(uint256 _startTime, uint256 _epochLength) external onlyOperator {
        require(!epochInitialized, "alreadyInitialized");
        require(_startTime > block.timestamp, "startTimeInThePast");
        epochStartTime = _startTime;
        epochLength = _epochLength;
        lastEpochTimestamp = _startTime.sub(_epochLength);
        epochInitialized = true;
    }

    // Add new Pool
    function addPool(address pool_address) public onlyOperator {
        require(!isPool(pool_address), "poolExisted");
        pools[pool_address] = true;
        pools_array.push(pool_address);
        emit PoolAdded(pool_address);
    }

    // Remove a pool
    function removePool(address pool_address) public onlyOperator {
        require(pools[pool_address], "!pool");
        // Delete from the mapping
        delete pools[pool_address];
        // 'Delete' from the array without leaving a hole
        for (uint256 i = 0; i < pools_array.length; i++) {
            if (pools_array[i] == pool_address) {
                pools_array[i] = pools_array[pools_array.length - 1];
                break;
            }
        }
        pools_array.pop();
        emit PoolRemoved(pool_address);
    }

    function addFoundry(address _foundry, address _pool) external onlyOperator {
        require(isPool(_pool), "!pool");
        foundries[_pool] = _foundry;
        pool_by_foundry[_foundry] = _pool;
        emit FoundryAdded(_foundry, _pool);
    }

    function removeFoundry(address _foundry, address _pool) external onlyOperator {
        require(isPool(_pool), "!pool");
        delete foundries[_pool];
        delete pool_by_foundry[_foundry];
        emit FoundryRemoved(_foundry, _pool);
    }

    function setEpochDuration(uint256 duration) public onlyOperator {
        epochLength = duration;
    }

    function setUtilizationRatio(address _pool, uint256 _ratio) public onlyOperator {
        require(_pool != address(0), "invalidAddress");
        require(isPool(_pool), "pool_not_existed");
        require(_ratio <= UTILIZATION_RATION_MAX, "Utilization ratio too large");
        utilizationRatiosMapping[_pool] = _ratio;
        emit UtilizationRatioChanged(_pool, _ratio);
    }

    function setCollateralReserve(address _collateralReserve) external onlyOperator {
        require(_collateralReserve != address(0), "invalidAddress");
        collateralReserve = _collateralReserve;
        emit CollateralReserveChanged(collateralReserve);
    }
}
