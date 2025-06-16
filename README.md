# <h1 align="center"> Forge Template </h1>

**Template repository for getting started quickly with Foundry projects**

![Github Actions](https://github.com/foundry-rs/forge-template/workflows/CI/badge.svg)

## Getting Started

Click "Use this template" on [GitHub](https://github.com/foundry-rs/forge-template) to create a new repository with this repo as the initial state.

Or, if your repo already exists, run:
```sh
forge init
forge build
forge test
```

## Writing your first test

All you need is to `import forge-std/Test.sol` and then inherit it from your test contract. Forge-std's Test contract comes with a pre-instatiated [cheatcodes environment](https://book.getfoundry.sh/cheatcodes/), the `vm`. It also has support for [ds-test](https://book.getfoundry.sh/reference/ds-test.html)-style logs and assertions. Finally, it supports Hardhat's [console.log](https://github.com/brockelmore/forge-std/blob/master/src/console.sol). The logging functionalities require `-vvvv`.

```solidity
pragma solidity 0.8.10;

import "forge-std/Test.sol";

contract ContractTest is Test {
    function testExample() public {
        vm.roll(100);
        console.log(1);
        emit log("hi");
        assertTrue(true);
    }
}
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
