# Lagrange ZK Prover Network Contracts

This repository contains smart contracts for the Lagrange ZK Prover Network. These contracts are designed to manage queries, responses, and client interactions within the LPN ecosystem.

You can read [additional documentation here](https://docs.lagrange.dev/zk-coprocessor/euclid-testnet/overview)

You can see the [Lagrange ZK Prover Network AVS Contracts here](https://github.com/Lagrange-Labs/zkmr-avs-contracts)

## Commands and Scripts

### Environment Setup
Be sure to include a `.env` file and export the environment variables shown in `.env.example`

### Installation
Install dependencies:
```bash
$ forge install
$ forge update
```

### Build & Test
```bash
$ forge build
$ forge test
$ forge test -vvv
```

### Deployment
```bash
# Local development
$ make DeployLPNRegistryV1_local
$ make DeployLPNQueryV1_local

# Deploy / Upgrade Testnet
$ make DeployLPNRegistryV1_holesky

# Deploy to Mainnet
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

## Key Features

- Currently Supports ERC721Enumerable tokenId and ERC20 balance queries (with generalized SQL queries of any contract states coming soon!)
- Implements a registry for managing storage contract indexing + query requests and callbacks
- Supports deployment on multiple networks (anvil, holesky, mainnet, base, fraxtal, mantle)

## Contract Interactions

1. Storage contracts registered for indexing + proving with `LPNRegistryV0`
2. Query requests + verification and callback with `LPNRegistryV0`
2. Users can make queries by deploying a client contract that implements `LPNClientV0`. See `LPNQueryV0` for an example
3. The ZK Proving Network indexes storage contracts and proves queries of historical state from these contracts
4. Verified results are returned via the `processCallback` function implemented in the user's smart contract

## Key Structs and Contracts

### QueryParams
Represents parameters for different types of queries (NFT and ERC20).

```solidity
struct NFTQueryParams {
    uint8 identifier;
    address userAddress;
    uint88 offset;
}

struct ERC20QueryParams {
    uint8 identifier;
    address userAddress;
    uint88 rewardsRate;
}
```

### LPNRegistryV0
Main contract for managing storage contract registration + query requests + query verification and results callback

```solidity
contract LPNRegistryV0 is ILPNRegistry, OwnableWhitelist, Initializable {
    // Key functions
    function register(address storageContract, uint256 mappingSlot, uint256 lengthSlot) external;
    function request(address storageContract, bytes32 params, uint256 startBlock, uint256 endBlock) external payable returns (uint256);
    function respond(uint256 requestId_, bytes32[] calldata data, uint256 blockNumber) external;
}
```

### LPNClientV0
Abstract contract for LPN clients.

```solidity
abstract contract LPNClientV0 is ILPNClient {
    function lpnCallback(uint256 requestId, uint256[] calldata results) external;
    function processCallback(uint256 requestId, uint256[] calldata results) internal virtual;
}
```

### LPNQueryV0
Example contract for querying NFT ownership and ERC20 balances using the Lagrange Proving Network.

```solidity
contract LPNQueryV0 is LPNClientV0 {
    function queryNFT(address storageContract, address holder, uint256 startBlock, uint256 endBlock, uint88 offset) external payable;
    function queryERC20(address storageContract, address holder, uint256 startBlock, uint256 endBlock, uint88 rewardsRate) external payable;
}
```

# Credit - [Gnark](https://github.com/Consensys/gnark)
We would like to thank and recognize Consensys and the gnark team for their work, which we use to generate a Solidity verifier for onchain verification of our proofs.
