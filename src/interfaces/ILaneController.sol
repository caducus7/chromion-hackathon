// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILaneController {
    function buyLaneTokens(uint256 roundId, uint256 laneId, uint256 amount) external;
    function startRace(uint256 roundId) external;
    function declareWinner(uint256 roundId, uint256 laneId) external;
    function distributePrizes(uint256 roundId) external;
    function createNewRound(uint64[][] calldata lanes) external returns (uint256);
} 