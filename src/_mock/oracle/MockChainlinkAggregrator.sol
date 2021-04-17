// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

contract MockChainlinkAggregrator {
    uint80 public _roundId = 0;
    uint256 public _answer;
    uint256 public _startedAt = 0;
    uint256 public _updatedAt = 0;
    uint256 public decimals = 8;

    constructor(uint256 answer) {
        _answer = answer;
    }

    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            uint256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = _roundId;
        answer = _answer;
        startedAt = _startedAt;
        updatedAt = _updatedAt;
        answeredInRound = 0;
    }
}
