
```

## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.

# Lane Checker

Lane Checker is a competitive cross-chain racing game leveraging Chainlink CCIP, VRF, and Automation. Players bet on "lanes" (token racing paths) that hop across multiple EVM chains. The first lane to complete its circuit wins the prize pool.

## Core Architecture

- **Lane Racing**: Multiple concurrent racing lanes across different chain paths
- **Tokenized Betting**: Players buy Lane Tokens (LT) representing positions in specific lanes
- **Cross-Chain Hops**: Lane Tokens use Chainlink CCIP to hop between predetermined chain circuits
- **VRF Chain Selection**: Chainlink VRF adds randomness to next-hop decisions within lane constraints
- **Winner-Takes-Most**: 70% prize pool to winning lane holders, 15% platform fee, 10% gas reserve, 5% runner-up

## Technical Stack

- **Framework**: Foundry with Chainlink Local for multi-chain testing
- **Cross-Chain**: Chainlink CCIP with CCT (Cross-Chain Token) standard
- **Randomness**: Chainlink VRF for fair chain selection
- **Automation**: Chainlink Automation for game scheduling
- **Testing**: Multi-fork testing with historical chain states

## Setup

1. Install dependencies:
   ```bash
   forge install smartcontractkit/chainlink-brownie-contracts
   forge install smartcontractkit/chainlink-local
   forge install OpenZeppelin/openzeppelin-contracts
   forge install foundry-rs/forge-std
   ```
2. Copy `.env.example` to `.env` and fill in your RPC endpoints and keys.
3. Build and test:
   ```bash
   forge build
   forge test
   ```

## Directory Structure

See the project prompt for a detailed directory and file structure.
