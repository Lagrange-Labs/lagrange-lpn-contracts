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
        // cannont calculate blockhash for a pending block, we can only lookup the blockhash of
        // the latest confirmed block
        return blockhash(block.number - 1);
    }

    if (isOPStack()) {
        return IOptimismL1Block(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR).hash();
    }

    return bytes32(0);
}

/// @notice The latest L1 block number.
function L1BlockNumber() view returns (uint256) {
    if (isEthereum()) {
        // block.number is the "pending" block, not actually the tip of the chain,
        // see comment on blockhash above
        return block.number - 1;
    }

    if (isOPStack()) {
        return
            uint256(IOptimismL1Block(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR).number());
    }

    return 0;
}
