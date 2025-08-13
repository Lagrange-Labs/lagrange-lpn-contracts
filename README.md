# Lagrange ZK Prover Network Contracts

This repository contains smart contracts for the Lagrange ZK Prover Network. These contracts are designed to manage queries, responses, and client interactions within the LPN ecosystem.

You can find the [user documentation here](https://docs.lagrange.dev/zk-coprocessor/overview)

# Guide for Maintainers

## Environment Setup
Be sure to include a `.env` file and export the environment variables shown in `.env.example`

## Pre-requisites
- [Foundry](https://book.getfoundry.sh)
- Make

## Installation
Install dependencies:
```bash
forge install
forge soldeer install
```

## Optional:

* Docker (for running slither)
* [Aderyn](https://github.com/Cyfrin/aderyn)
* [Glow](https://github.com/charmbracelet/glow) (for reading markdown reports)
* [Lintspec](https://github.com/beeb/lintspec) (for running the Natspec linter)

## Build & Test
```bash
forge build
forge test
```

## Run Static Analysis

```bash
make slither
make aderyn
```

## Deploy

* Private key and Etherscan API key *must* be supplied as environment variables.
* Set the appropriate `ENV` var: prod, test, or dev-X
* Only 9/10 contracts will verify because the [Deployer](./src/v2/Deployer.sol) contract self-destructs.
* Ensure the RPC is configured for the chain you want to deploy to in foundry.toml
* Note that md5 is a required system dependency, make sure you have it installed

```bash
export PRIVATE_KEY=<...>
export ETHERSCAN_API_KEY=<...>
export ENV=<dev-x/test/prod>
make deploy-v2 [chain]
```

## Update

To update the verifier contract on a dev environment, the command is:

```bash
export PRIVATE_KEY=<...>
export ETHERSCAN_API_KEY=<...>
export ENV=<dev-x/test/prod>
make update-v2-executors
```

## Design

See the following design docs:
* [ZK-Coprocessor System Overview](docs/coprocessor-system-overview.md)

## Credit - [Gnark](https://github.com/Consensys/gnark)
We would like to thank and recognize Consensys and the gnark team for their work, which we use to generate a Solidity verifier for onchain verification of our proofs.
