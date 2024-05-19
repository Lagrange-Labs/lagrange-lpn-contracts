// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IOptimismL1Block} from "../interfaces/IOptimismL1Block.sol";

uint256 constant LOCAL = 1337;
uint256 constant ANVIL = 31337;

uint256 constant ETH_MAINNET = 1;
uint256 constant ETH_SEPOLIA = 11155111;
uint256 constant ETH_HOLESKY = 17000;

uint256 constant BASE_MAINNET = 8453;
uint256 constant BASE_SEPOLIA = 84532;

uint256 constant FRAXTAL_MAINNET = 252;
uint256 constant FRAXTAL_HOLESKY = 2522;

address constant OP_STACK_L1_BLOCK_PREDEPLOY_ADDR =
    0x4200000000000000000000000000000000000015;

address constant L1_BASE_BRIDGE = 0x3154Cf16ccdb4C6d922629664174b904d80F2C35;
address constant L1_FRAXTAL_BRIDGE = 0x34C0bD5877A5Ee7099D0f5688D65F4bB9158BDE2;
address constant L1_FRAXTAL_HOLESKY_BRIDGE =
    0x0BaafC217162f64930909aD9f2B27125121d6332;

address constant PUDGEY_PENGUINS = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;

uint256 constant PUDGEY_PENGUINS_MAPPING_SLOT = 2;
uint256 constant PUDGEY_PENGUINS_LENGTH_SLOT = 8;

uint256 constant LAGRANGE_LOONS_MAPPING_SLOT = 2;
uint256 constant LAGRANGE_LOONS_LENGTH_SLOT = 8;

function isEthereum() view returns (bool) {
    return block.chainid == ETH_MAINNET || block.chainid == ETH_SEPOLIA;
}

function isOPStack() view returns (bool) {
    uint32 size;
    assembly {
        size := extcodesize(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR)
    }
    return (size > 0);
}

function isLocal() view returns (bool) {
    return block.chainid == LOCAL || block.chainid == ANVIL;
}

function isTestnet() view returns (bool) {
    uint256[4] memory testnets =
        [ETH_SEPOLIA, ETH_HOLESKY, BASE_SEPOLIA, FRAXTAL_HOLESKY];
    return chainMatches(testnets);
}

function isMainnet() view returns (bool) {
    uint256[3] memory mainnets = [ETH_MAINNET, BASE_MAINNET, FRAXTAL_MAINNET];
    return chainMatches(mainnets);
}

function chainMatches(uint256[3] memory chains) view returns (bool) {
    for (uint256 i = 0; i < chains.length; i++) {
        if (chains[i] == block.chainid) return true;
    }
    return false;
}

function chainMatches(uint256[4] memory chains) view returns (bool) {
    for (uint256 i = 0; i < chains.length; i++) {
        if (chains[i] == block.chainid) return true;
    }
    return false;
}
