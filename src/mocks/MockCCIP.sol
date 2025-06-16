// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockCCIP {
    event MessageSent(uint64 destinationChainSelector, bytes message);
    event MessageReceived(uint64 sourceChainSelector, bytes message);

    function ccipSend(uint64 destinationChainSelector, bytes calldata message) external returns (bytes32) {
        emit MessageSent(destinationChainSelector, message);
        return keccak256(abi.encode(destinationChainSelector, message, block.timestamp));
    }

    function ccipReceive(uint64 sourceChainSelector, bytes calldata message) external {
        emit MessageReceived(sourceChainSelector, message);
    }
} 