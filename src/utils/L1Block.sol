// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOptimismL1Block} from "../interfaces/IOptimismL1Block.sol";
import {
    ETH_MAINNET,
    ETH_SEPOLIA,
    BASE_MAINNET,
    BASE_SEPOLIA,
    OP_STACK_L1_BLOCK_PREDEPLOY_ADDR
} from "./Constants.sol";

/// @title L1Block
/// @notice The L1Block predeploy gives users access to information about the last known L1 block.
contract L1Block {
    /// @notice The latest L1 blockhash.
    function L1BlockHash(uint256 blockNumber) internal returns (bytes32) {
        if (isEthereum()) {
            return blockhash(blockNumber);
        }

        if (isOPStack()) {
            return IOptimismL1Block(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR).hash();
        }

        return bytes32(0);
    }

    function L1BlockNumber() internal returns (uint256) {
        if (isEthereum()) {
            return block.number;
        }

        if (isOPStack()) {
            return uint256(
                IOptimismL1Block(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR).number()
            );
        }

        return 0;
    }

    function isEthereum() internal view returns (bool) {
        return block.chainid == ETH_MAINNET || block.chainid == ETH_SEPOLIA;
    }

    function isOPStack() internal view returns (bool) {
        return block.chainid == BASE_MAINNET || block.chainid == BASE_SEPOLIA;
    }
}
