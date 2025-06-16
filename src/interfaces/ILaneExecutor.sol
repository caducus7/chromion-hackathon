// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILaneExecutor {
    function ccipReceive(bytes calldata message) external;
    function simulateDeFiOperation(uint256 roundId, uint256 laneId, uint256 hopIndex) external;
    function requestNextHop(uint256 roundId, uint256 laneId, uint256 hopIndex) external;
    function executeNextHop(uint256 roundId, uint256 laneId, uint256 hopIndex, uint256 amount) external;
} 