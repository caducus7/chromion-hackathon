// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LaneToken is CCIPReceiver, VRFConsumerBaseV2 {
    struct GameRound {
        address initiator;
        uint8 hopCount;
        uint8 maxHops;
        uint256 totalLatency;
        uint256 lastSendTime;
        uint256 amount;
        bool isActive;
    }

    IERC20 public immutable i_underlyingToken;
    mapping(address => uint256) public s_balances;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_vrfSubscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 public s_gameCounter;
    mapping(uint256 => GameRound) public s_gameRounds;
    mapping(bytes32 => uint256) public s_messageIdToGameId;
    mapping(uint256 => uint256) public s_vrfRequestToGameId;
    uint256[] public s_supportedChainSelectors;
    IRouterClient public immutable s_router;

    event GameRoundStarted(uint256 indexed gameId, address indexed initiator, uint256 amount, uint8 maxHops);
    event HopCompleted(uint256 indexed gameId, uint64 fromChain, uint256 latency, uint8 hopCount);
    event GameFinished(uint256 indexed gameId, uint256 totalLatency, uint8 totalHops);
    event BridgeStarted(bytes32 indexed messageId, uint64 destChainSelector, uint256 amount);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event HopReceived(bytes32 indexed messageId, uint64 sourceChainSelector, uint256 amount);
    event NextHopRequested(uint256 indexed requestId);

    constructor(
        address _router,
        address _underlyingToken,
        address _vrfCoordinator,
        uint64 _vrfSubscriptionId,
        bytes32 _gasLane,
        uint256[] memory _supportedChains
    ) CCIPReceiver(_router) VRFConsumerBaseV2(_vrfCoordinator) {
        i_underlyingToken = IERC20(_underlyingToken);
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_vrfSubscriptionId = _vrfSubscriptionId;
        i_gasLane = _gasLane;
        s_supportedChainSelectors = _supportedChains;
        s_router = IRouterClient(_router);
    }

    function deposit(uint256 _amount) external {
        i_underlyingToken.transferFrom(msg.sender, address(this), _amount);
        s_balances[msg.sender] += _amount;
        emit Deposited(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        require(s_balances[msg.sender] >= _amount, "Insufficient balance");
        s_balances[msg.sender] -= _amount;
        i_underlyingToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function startGame(uint64 _destinationChainSelector, uint256 _amount, uint8 _maxHops) external returns (bytes32 messageId) {
        require(s_balances[msg.sender] >= _amount, "Insufficient balance");
        s_balances[msg.sender] -= _amount;

        s_gameCounter++;
        uint256 gameId = s_gameCounter;

        s_gameRounds[gameId] = GameRound({
            initiator: msg.sender,
            hopCount: 0,
            maxHops: _maxHops,
            totalLatency: 0,
            lastSendTime: block.timestamp,
            amount: _amount,
            isActive: true
        });

        bytes memory messageData = abi.encode(gameId, block.timestamp);
        messageId = _bridge(_destinationChainSelector, _amount, messageData);
        s_messageIdToGameId[messageId] = gameId;

        emit GameRoundStarted(gameId, msg.sender, _amount, _maxHops);
        return messageId;
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (uint256 gameId, uint256 sendTime) = abi.decode(message.data, (uint256, uint256));
        require(s_gameRounds[gameId].isActive, "Game is not active");

        uint256 latency = block.timestamp - sendTime;
        s_gameRounds[gameId].totalLatency += latency;
        s_gameRounds[gameId].hopCount++;

        if (s_gameRounds[gameId].hopCount >= s_gameRounds[gameId].maxHops) {
            s_gameRounds[gameId].isActive = false;
            s_balances[s_gameRounds[gameId].initiator] += s_gameRounds[gameId].amount;
            emit GameFinished(gameId, s_gameRounds[gameId].totalLatency, s_gameRounds[gameId].hopCount);
            return;
        }

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_vrfSubscriptionId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, NUM_WORDS
        );
        s_vrfRequestToGameId[requestId] = gameId;
        emit NextHopRequested(requestId);
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 gameId = s_vrfRequestToGameId[_requestId];
        require(gameId != 0, "Invalid VRF request");
        require(s_gameRounds[gameId].isActive, "Game is not active");
        uint256 randomIndex = _randomWords[0] % s_supportedChainSelectors.length;
        uint64 nextChainSelector = uint64(s_supportedChainSelectors[randomIndex]);
        s_gameRounds[gameId].lastSendTime = block.timestamp;
        bytes memory messageData = abi.encode(gameId, s_gameRounds[gameId].lastSendTime);
        bytes32 messageId = _bridge(nextChainSelector, s_gameRounds[gameId].amount, messageData);
        s_messageIdToGameId[messageId] = gameId;
    }

    function _bridge(uint64 _destinationChainSelector, uint256 _amount, bytes memory _messageData) internal returns (bytes32 messageId) {
        i_underlyingToken.approve(address(s_router), _amount);
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(i_underlyingToken), amount: _amount});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(address(this)),
            data: _messageData,
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: address(0)
        });
        uint256 fee = s_router.getFee(_destinationChainSelector, message);
        messageId = s_router.ccipSend{value: fee}(_destinationChainSelector, message);
        emit BridgeStarted(messageId, _destinationChainSelector, _amount);
        return messageId;
    }

    function getGameRound(uint256 gameId) external view returns (
        address player,
        uint256 amount,
        uint8 maxHops,
        uint8 hopsCompleted,
        uint256 totalLatency,
        uint256 lastSendTime,
        bool isActive
    ) {
        GameRound storage round = s_gameRounds[gameId];
        return (
            round.initiator,
            round.amount,
            round.maxHops,
            round.hopCount,
            round.totalLatency,
            round.lastSendTime,
            round.isActive
        );
    }
} 