// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {StdChains} from "forge-std/StdChains.sol";
import {
    MANTLE_MAINNET,
    MANTLE_SEPOLIA,
    POLYGON_ZKEVM_MAINNET,
    SCROLL_SEPOLIA
} from "./Constants.sol";

/// @notice This contract is used to register non-default chains for deployment scripts and tests
/// @dev https://github.com/foundry-rs/forge-std/issues/440#issuecomment-1696115446
abstract contract ChainConnections is StdChains {
    constructor() {
        setChain(
            "mantle",
            ChainData("Mantle", MANTLE_MAINNET, "https://rpc.mantle.xyz")
        );
        setChain(
            "mantle_sepolia",
            ChainData(
                "Mantle Sepolia",
                MANTLE_SEPOLIA,
                "https://rpc.sepolia.mantle.xyz"
            )
        );
        setChain(
            "polygon_zkevm",
            ChainData(
                "Polygon zkEVM", POLYGON_ZKEVM_MAINNET, "https://zkevm-rpc.com"
            )
        );
        setChain(
            "scroll_sepolia",
            ChainData(
                "Scroll Sepolia",
                SCROLL_SEPOLIA,
                "https://sepolia-rpc.scroll.io"
            )
        );
        setChain("mantle", ChainData("Mantle", 5000, "https://rpc.mantle.xyz"));
    }
}
