// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOptimismL1Block} from "../interfaces/IOptimismL1Block.sol";

uint256 constant LOCAL = 1337;
uint256 constant ANVIL = 31337;

uint256 constant ETH_MAINNET = 1;
uint256 constant ETH_SEPOLIA = 11155111;
uint256 constant BASE_MAINNET = 8453;
uint256 constant BASE_SEPOLIA = 84532;

address constant OP_STACK_L1_BLOCK_PREDEPLOY_ADDR =
    0x4200000000000000000000000000000000000015;

address constant PUDGEY_PENGUINS = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;

uint256 constant PUDGEY_PENGUINS_MAPPING_SLOT = 2;
uint256 constant PUDGEY_PENGUINS_LENGTH_SLOT = 8;

uint256 constant LAGRANGE_LOONS_MAPPING_SLOT = 2;
uint256 constant LAGRANGE_LOONS_LENGTH_SLOT = 8;

function isEthereum() view returns (bool) {
    return block.chainid == ETH_MAINNET || block.chainid == ETH_SEPOLIA;
}

function isOPStack() view returns (bool) {
    return block.chainid == BASE_MAINNET || block.chainid == BASE_SEPOLIA;
}

function isTestnet() view returns (bool) {
    return block.chainid == ETH_SEPOLIA || block.chainid == BASE_SEPOLIA;
}

function isMainnet() view returns (bool) {
    return block.chainid == ETH_MAINNET || block.chainid == BASE_MAINNET;
}

function isLocal() view returns (bool) {
    return block.chainid == LOCAL || block.chainid == ANVIL;
}
