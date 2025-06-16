// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LaneToken} from "../../src/core/LaneToken.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockCCIPRouter} from "../../src/mocks/MockCCIPRouter.sol";
import {MockVRFCoordinatorV2} from "../../src/mocks/MockVRFCoordinatorV2.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

contract LaneTokenStatefulTest is Test {
    // Contracts
    LaneToken public laneToken;
    MockERC20 public mockUsdc;
    MockCCIPRouter public mockRouter;
    MockVRFCoordinatorV2 public mockVrfCoordinator;

    // Test Users
    address public player = makeAddr("player");
    address public initiator = makeAddr("initiator"); // For internal calls

    // Constants
    uint64 constant MUMBAI_SELECTOR = 12532609583862916517;
    uint64 constant FUJI_SELECTOR = 14767482510784806043;
    uint256 constant START_AMOUNT = 10 * 1e6; // 10 USDC

    // Event declarations for vm.expectEmit
    event GameRoundStarted(uint256 indexed gameId, address indexed initiator, uint256 amount, uint8 maxHops);
    event BridgeStarted(bytes32 indexed messageId, uint64 destChainSelector, uint256 amount);
    event HopCompleted(uint256 indexed gameId, uint64 fromChain, uint256 latency, uint8 hopCount);
    event GameFinished(uint256 indexed gameId, uint256 totalLatency, uint8 totalHops);
    event NextHopRequested(uint256 indexed requestId);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        mockUsdc = new MockERC20("Mock USDC", "mUSDC", 6);
        mockRouter = new MockCCIPRouter();
        mockVrfCoordinator = new MockVRFCoordinatorV2();

        uint64 subscriptionId = 1;
        bytes32 gasLane = bytes32(0);
        uint256[] memory supportedChains = new uint256[](2);
        supportedChains[0] = MUMBAI_SELECTOR;
        supportedChains[1] = FUJI_SELECTOR;

        laneToken = new LaneToken(
            address(mockRouter),
            address(mockUsdc),
            address(mockVrfCoordinator),
            subscriptionId,
            gasLane,
            supportedChains
        );

        mockUsdc.mint(player, START_AMOUNT);
        vm.startPrank(player);
        mockUsdc.approve(address(laneToken), START_AMOUNT);
        laneToken.deposit(START_AMOUNT);
        vm.stopPrank();
    }

    /*
     * @notice Tests if startGame correctly initializes a GameRound.
     */
    function test_StartGame() public {
        console.log("--- Running test_StartGame ---");
        vm.startPrank(player);

        // CORRECTED: Expect all 3 events in the correct order.
        // Event 1: The internal approval from LaneToken to the router
        vm.expectEmit(true, true, false, true);
        emit Approval(address(laneToken), address(mockRouter), START_AMOUNT);

        // Event 2: The bridge starting
        vm.expectEmit(true, true, false, false);
        emit BridgeStarted(bytes32(uint256(1)), MUMBAI_SELECTOR, START_AMOUNT);

        // Event 3: The game round officially starting
        vm.expectEmit(true, true, false, false);
        emit GameRoundStarted(1, player, START_AMOUNT, 3);

        console.log("Player calling startGame...");
        laneToken.startGame(MUMBAI_SELECTOR, START_AMOUNT, 3);
        console.log("startGame call finished.");

        vm.stopPrank();

        (,,,,,,bool isActive) = laneToken.getGameRound(1);
        assertTrue(isActive);
    }

    /*
     * @notice Tests a full game cycle: Start -> 1 Hop -> VRF -> 2nd Hop -> Finish
     */
    function test_FullMultiHopGame() public {
        console.log("\n--- Running test_FullMultiHopGame ---");
        uint8 maxHops = 2;

        // --- 1. Start the game ---
        vm.startPrank(player);
        console.log("Player starting game for multi-hop test...");

        // CORRECTED: Expect all 3 events in the correct order for the startGame call.
        vm.expectEmit(true, true, false, true);
        emit Approval(address(laneToken), address(mockRouter), START_AMOUNT);
        vm.expectEmit(true, true, false, false);
        emit BridgeStarted(bytes32(uint256(1)), MUMBAI_SELECTOR, START_AMOUNT);
        vm.expectEmit(true, true, false, false);
        emit GameRoundStarted(1, player, START_AMOUNT, maxHops);
        
        laneToken.startGame(MUMBAI_SELECTOR, START_AMOUNT, maxHops);
        vm.stopPrank();
        console.log("Game started successfully.");

        uint256 gameId = 1;
        (,,,,,,bool isActive2) = laneToken.getGameRound(gameId);
        (,,,,,uint256 lastSendTime,) = laneToken.getGameRound(gameId);

        // --- 2. Simulate Hop 1 Arrival ---
        uint256 timePassed = 300;
        vm.warp(block.timestamp + timePassed);

        bytes memory messageData = abi.encode(gameId, lastSendTime);
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(uint256(0x123)),
            sourceChainSelector: MUMBAI_SELECTOR,
            sender: abi.encode(initiator),
            data: messageData,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        console.log("Simulating Hop 1 arrival (_ccipReceive)...");
        vm.expectEmit(true, true, false, false); // HopCompleted
        emit HopCompleted(gameId, MUMBAI_SELECTOR, timePassed, 1);
        vm.expectEmit(true, false, false, true); // NextHopRequested
        emit NextHopRequested(1);
        vm.prank(address(mockRouter));
        laneToken.ccipReceive(message);
        console.log("_ccipReceive finished. Hop 1 completed.");

        // --- 3. Simulate VRF Fulfillment & Hop 2 Departure ---
        console.log("Simulating VRF fulfillment...");
        uint256 requestId = 1;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 99; // selects Fuji (index 1)
        // Expect Approval event for the second hop
        vm.expectEmit(true, true, false, true);
        emit Approval(address(laneToken), address(mockRouter), START_AMOUNT);
        // Expect BridgeStarted for Hop 2
        vm.expectEmit(true, true, false, false);
        emit BridgeStarted(bytes32(uint256(2)), FUJI_SELECTOR, START_AMOUNT);
        mockVrfCoordinator.fulfillRandomWords(requestId, address(laneToken), randomWords);
        console.log("VRF fulfilled. Hop 2 departed.");

        // --- 4. Simulate Final Hop Arrival & Game End ---
        vm.warp(block.timestamp + timePassed);
        messageData = abi.encode(gameId, block.timestamp - timePassed);
        message.data = messageData;
        message.sourceChainSelector = FUJI_SELECTOR;
        console.log("Simulating Final Hop arrival (_ccipReceive)...");
        // Only expect HopCompleted and GameFinished for the final hop
        console.log("[Test] Expecting HopCompleted:");
        console.log(gameId);
        console.log(FUJI_SELECTOR);
        console.log(timePassed);
        console.log(uint256(2));
        vm.expectEmit(true, true, false, false);
        emit HopCompleted(gameId, FUJI_SELECTOR, timePassed, 2);
        console.log("[Test] Expecting GameFinished:");
        console.log(gameId);
        console.log(timePassed * 2);
        console.log(uint256(2));
        vm.expectEmit(true, true, false, false);
        emit GameFinished(gameId, timePassed * 2, 2);
        vm.prank(address(mockRouter));
        laneToken.ccipReceive(message);
        console.log("_ccipReceive finished. Game has ended.");
    }
} 
       