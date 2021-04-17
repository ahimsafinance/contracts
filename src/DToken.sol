// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";

import "./ERC20/ERC20Custom.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IDToken.sol";
import "./Operator.sol";

contract DToken is ERC20Custom, IDToken, Operator {
    using SafeMath for uint256;

    // ERC20
    string public symbol;
    string public name;
    uint8 public constant decimals = 18;

    // CONTRACTS
    address public treasury;

    // FLAGS
    bool public initialized;

    /* ========== MODIFIERS ========== */

    modifier onlyPool() {
        require(ITreasury(treasury).isMintingPool(msg.sender, address(this)), "Only pool can mint DToken");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        string memory _name,
        string memory _symbol,
        address _treasury
    ) {
        name = _name;
        symbol = _symbol;
        treasury = _treasury;
    }

    function initialize(uint256 genesis_supply) external onlyOperator {
        require(!initialized, "DToken was already initialized");
        initialized = true;
        _mint(_msgSender(), genesis_supply);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function poolBurnFrom(address _address, uint256 _amount) external override onlyPool {
        super._burnFrom(_address, _amount);
        emit DTokenBurned(_address, msg.sender, _amount);
    }

    function poolMint(address _address, uint256 _amount) external override onlyPool {
        super._mint(_address, _amount);
        emit DTokenMinted(msg.sender, _address, _amount);
    }

    function setTreasury(address _treasury) public onlyOperator {
        treasury = _treasury;
        emit TreasuryChanged(treasury);
    }

    /* ========== EVENTS ========== */

    event DTokenBurned(address indexed from, address indexed to, uint256 amount);
    event DTokenMinted(address indexed from, address indexed to, uint256 amount);
    event TreasuryChanged(address indexed newTreasury);
}
