// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILaneToken {
    function bridgeToChain(uint64 chainId, uint256 amount) external;
    function onTokenBridge(uint64 fromChain, bytes calldata data) external;
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
} 