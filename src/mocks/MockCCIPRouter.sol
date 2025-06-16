// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

contract MockCCIPRouter {
    event CCIPSendRequested(uint64 destinationChainSelector, address sender);

    function getFee(uint64, bytes memory) public pure returns (uint256) {
        return 0;
    }

    // Add this overload for compatibility with LaneToken
    function getFee(uint64, Client.EVM2AnyMessage memory) public pure returns (uint256) {
        return 0;
    }

    function ccipSend(uint64 destinationChainSelector, bytes memory) public payable returns (bytes32) {
        emit CCIPSendRequested(destinationChainSelector, msg.sender);
        return bytes32(0);
    }

    // Add this overload for compatibility with LaneToken
    function ccipSend(uint64, Client.EVM2AnyMessage memory) public payable returns (bytes32) {
        return bytes32(uint256(1));
    }
} 