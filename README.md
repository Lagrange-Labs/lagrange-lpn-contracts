# Lagrange ZK Prover Network Contracts

This repository contains smart contracts for the Lagrange ZK Prover Network. These contracts are designed to manage queries, responses, and client interactions within the LPN ecosystem.

You can find the [user documentation here](https://docs.lagrange.dev/zk-coprocessor/themis-testnet/overview)

You can see the [Lagrange ZK Prover Network AVS Contracts here](https://github.com/Lagrange-Labs/zkmr-avs-contracts)

# Guide for Maintainers

## Contract Addresses
You can find relevant deployed contract addresses in the `v1-deployment.json` files. e.g. [holesky v1-deployment.json](./script/output/holesky/v1-deployment.json)

## Environment Setup
Be sure to include a `.env` file and export the environment variables shown in `.env.example`

## Installation
Install dependencies:
```bash
$ forge install
$ forge update
```

## Build & Test
```bash
$ forge build
$ forge test
$ forge test -vvv
```

## Makefile & Commands
The commands in the [Makefile](./Makefile) are auto-generated based on:
- the *.s.sol filenames under the [script](./script) directory
- the `CHAINS` array defined in the `Makefile`

e.g.
```bash
$ make # Defaults to the `make usage` command
$ make list-scripts

$ make WhitelistZKMR_holesky # Runs the WhitelistZKMR script for the holesky chain
```

NOTE: In order for the command auto-generation to work, the script smart contract name MUST exactly match the solidity filename.

e.g. For [WhitelistZKMR.s.sol](./script/util/WhitelistZKMR.s.sol), the smart contract name in the script file must be `WhitelistZKMR`
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";

// This smart contract will not run
contract WhitelistBase is BaseScript {
    ...
}

// This smart contract will run
contract WhitelistZKMR is WhitelistBase {
    ...
}
```

### Deployment
```bash
# Local development
$ make DeployLPNRegistryV1_anvil
$ make DeployLPNQueryV1_anvil

# Deploy / Upgrade Devnet
$ make DeployLPNRegistryV1_holesky_dev

# Deploy / Upgrade Testnet
$ make DeployLPNRegistryV1_holesky

# Deploy / Upgrade Mainnet
$ make DeployLPNRegistryV1_mainnet
$ make DeployLPNRegistryV1_base
$ make DeployLPNRegistryV1_fraxtal
$ make DeployLPNRegistryV1_mantle
$ make DeployLPNRegistryV1_polygon_zkevm
```

### Queries
```bash
# Run queries on different networks
$ make Query_holesky

$ make Query_mainnet
$ make Query_base
$ make Query_fraxtal
$ make Query_mantle
```

### Whitelist
```bash
# Must set PRIVATE_KEY to testnet admin
$ make WhitelistZKMR_holesky

# Must submit from a multisig signer
$ make WhitelistZKMR_mainnet

# Must submit from a multisig signer
$ make WhitelistLSC_mainnet
```

### Withdrawing Fees
```bash
# Must submit all of these from a multisig signer
$ make WithdrawFees_mainnet
$ make WithdrawFees_base
$ make WithdrawFees_fraxtal
$ make WithdrawFees_mantle
$ make WithdrawFees_polygon_zkevm
```

### Multisig Admin Scripts
```bash
# Only required to run once for each newly supported chain
$ make DeployMultisig_base

# Must submit from a multisig signer
$ make UpdateMultisigSigners_polygon_zkevm \
  ARGS='--sig "run(address[],uint256)" "[0x1234...5678,0x5678...1234]" 2'
```

# Credit - [Gnark](https://github.com/Consensys/gnark)
We would like to thank and recognize Consensys and the gnark team for their work, which we use to generate a Solidity verifier for onchain verification of our proofs.
