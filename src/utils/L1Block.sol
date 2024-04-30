// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOptimismL1Block} from "../interfaces/IOptimismL1Block.sol";
import {
    OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
    isEthereum,
    isOPStack
} from "./Constants.sol";

/// @notice The latest L1 blockhash.
function L1BlockHash() view returns (bytes32) {
    if (isEthereum()) {
        return blockhash(block.number);
    }

    if (isOPStack()) {
        return IOptimismL1Block(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR).hash();
    }

    return bytes32(0);
}

/// @notice The latest L1 block number.
function L1BlockNumber() view returns (uint256) {
    if (isEthereum()) {
        return block.number;
    }

    if (isOPStack()) {
        return
            uint256(IOptimismL1Block(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR).number());
    }

    return 0;
}
