# Lagrange ZK Prover Network Contracts

This repository contains smart contracts for the Lagrange ZK Prover Network. These contracts are designed to manage queries, responses, and client interactions within the LPN ecosystem.

You can find the [user documentation here](https://docs.lagrange.dev/zk-coprocessor/themis-testnet/overview)

You can see the [Lagrange ZK Prover Network AVS Contracts here](https://github.com/Lagrange-Labs/zkmr-avs-contracts)

# Guide for Maintainers

## Contract Addresses
You can find relevant deployed contract addresses in the `v1-deployment.json` files. e.g.
- [holesky_dev v1-deployment.json](./script/output/holesky_dev/v1-deployment.json) (devnet)
- [holesky v1-deployment.json](./script/output/holesky/v1-deployment.json) (testnet)
- [mainnet v1-deployment.json](./script/output/mainnet/v1-deployment.json) (mainnet L1)

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

## Run Static Analysis
Requirements:
  * docker

```bash
$ make slither
```

## Makefile & Commands
The commands in the [Makefile](./Makefile) are auto-generated based on:
- the `*.s.sol` filenames under the [script](./script) directory
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

### Deployment / Upgrade
0. (prerequisite) If deploying to a new chain, first confirm that an ERC1967Factory is deployed to the chain. See [here](https://github.com/Vectorized/solady/blob/a2f53c1f15ed07671d805e3a4a0e306b2a09d3bc/src/utils/ERC1967FactoryConstants.sol#L8:L18) for deployment instructions if needed.
1. (optional) If circuit / parameter changes are required ensure they are:
    - Generated and uploaded to the appropriate bucket
    - The related circuit code changes are correctly versioned and scheduled for release
    - Operators for testnet + mainnet are notified of the update
    - The testnet / mainnet contract is upgraded during the release of the new code / circuits to the operators
2. Ensure desired changes to [Groth16Verifier.sol](./src/v1/Groth16Verifier.sol) are in the main branch of [mapreduce-plonky2](https://github.com/Lagrange-Labs/mapreduce-plonky2/blob/main/groth16-framework/test_data/verifier.sol)
3. Run the desired command:
```bash
# Local development
$ make DeployLPNRegistryV1_anvil
$ make DeployLPNQueryV1_anvil

# Deploy / Upgrade Devnetk
$ export ENV=dev-0
$ make DeployLPNRegistryV1_dev-0

# Deploy / Upgrade Testnet
$ export ENV=test
$ make DeployLPNRegistryV1_holesky

# Deploy / Upgrade Mainnet
$ export ENV=prod
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

First, add 1 or more new operator addresses to either:
- [holesky-operators.json](./config/holesky-operators.json)
- [mainnet-operators.json](./config/holesky-operators.json)

Then, run the appropriate command:
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
