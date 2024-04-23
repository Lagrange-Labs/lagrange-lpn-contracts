// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @custom:proxied
/// @custom:predeploy 0x4200000000000000000000000000000000000015
/// @title IOptimismL1Block
/// @notice from https://github.com/ethereum-optimism/optimism/blob/0d221da603418fe99e96bba944d2af64feee94eb/packages/contracts-bedrock/src/L2/L1Block.sol
///         The L1Block predeploy gives users access to information about the last known L1 block.
interface IOptimismL1Block {
    /// @notice The latest L1 blockhash.
    function hash() external returns (bytes32);

    /// @notice The latest L1 block number known by the L2 system.
    function number() external returns (uint64);
}
