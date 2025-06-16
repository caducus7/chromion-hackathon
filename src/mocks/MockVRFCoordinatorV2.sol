// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface VRFConsumerV2 {
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockVRFCoordinatorV2 {
    uint256 public lastRequestId;
    mapping(uint256 => address) public consumers;

    function requestRandomWords(
        bytes32, uint64, uint16, uint32, uint32
    ) external returns (uint256 requestId) {
        lastRequestId++;
        requestId = lastRequestId;
        consumers[requestId] = msg.sender;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, address consumer, uint256[] memory randomWords) public {
        // Call the consumer's rawFulfillRandomWords as the VRF coordinator
        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])", requestId, randomWords
            )
        );
        require(success, "fulfillment failed");
    }
} 