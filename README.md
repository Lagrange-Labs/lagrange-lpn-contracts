# Lagrange ZK Prover Network Contracts

This repository contains smart contracts for the Lagrange ZK Prover Network. These contracts are designed to manage queries, responses, and client interactions within the LPN ecosystem.

You can find the [user documentation here](https://docs.lagrange.dev/zk-coprocessor/overview)

# Guide for Maintainers

## Environment Setup
Be sure to include a `.env` file and export the environment variables shown in `.env.example`

## Pre-requisites
- [Foundry](https://book.getfoundry.sh)
- Docker (if you want to run slither)
- Make

## Installation
Install dependencies:
```bash
forge install
forge soldeer install
```

## Build & Test
```bash
forge build
forge test
```

## Run Static Analysis

```bash
make slither
```

## Deploy

* Private key and Etherscan API key *must* be supplied as environment variables.
* Only 8/9 contracts will verify because the [Deployer](./src/v2/Deployer.sol) contract self-destructs.

```bash
export PRIVATE_KEY=<...>
export ETHERSCAN_API_KEY=<...>
make deploy-v2 [chain]
```

## Design

See the following design docs:
* [ZK-Coprocessor System Overview](docs/coprocessor-system-overview.md)

## Credit - [Gnark](https://github.com/Consensys/gnark)
We would like to thank and recognize Consensys and the gnark team for their work, which we use to generate a Solidity verifier for onchain verification of our proofs.
