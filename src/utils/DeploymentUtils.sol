// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {ChainConnections} from "./ChainConnections.sol";

/// @notice This contract contains many utility functions for deployment scripts
abstract contract DeploymentUtils is ChainConnections, Script {
    address private deployerAddress;

    string private env;
    mapping(string env => string[] chains) private chainsByEnv;

    mapping(uint256 chainId => address addr) private engMultiSigs;
    mapping(uint256 chainId => address addr) private financeMultiSigs;

    constructor() {
        // Deployer Key
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.addr(deployerKey);
        vm.rememberKey(deployerKey);

        // Environments
        env = vm.envString("ENV");
        _validateEnv();
        // Dev
        chainsByEnv["dev-0"] = ["holesky"];
        chainsByEnv["dev-1"] = ["holesky"];
        chainsByEnv["dev-3"] = ["holesky"];
        // Test
        chainsByEnv["test"] = [
            "base_sepolia",
            "fraxtal_testnet",
            "holesky",
            "mantle_sepolia",
            "scroll_sepolia",
            "sepolia"
        ];
        // Prod
        chainsByEnv["prod"] =
            ["mainnet", "base", "mantle", "polygon_zkevm", "scroll", "fraxtal"];

        // Multi-sigs
        // Mainnet
        engMultiSigs[1] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[1] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Base
        engMultiSigs[8453] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[8453] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Mantle
        engMultiSigs[5000] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[5000] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Holesky
        engMultiSigs[17000] = 0x4584E9d4685E9Ffcc2d2823D016A08BA72Ad555f;
        financeMultiSigs[17000] = 0x4584E9d4685E9Ffcc2d2823D016A08BA72Ad555f;
        // Sepolia
        engMultiSigs[11155111] = 0x28670dAFD8F88f8f4b638E66c01d33A39b614Da6;
        financeMultiSigs[11155111] = 0x28670dAFD8F88f8f4b638E66c01d33A39b614Da6;
        // Fraxtal Testnet
        engMultiSigs[2522] = 0x85AC3c40e4227Af5993FC4dABe46D8D6493989fb;
        financeMultiSigs[2522] = 0x85AC3c40e4227Af5993FC4dABe46D8D6493989fb;
        // Scroll Sepolia
        engMultiSigs[534351] = 0x7fB320649abb0333b309ee876c68a1d2cd722429;
        financeMultiSigs[534351] = 0x7fB320649abb0333b309ee876c68a1d2cd722429;
        // Base Sepolia
        engMultiSigs[84532] = 0x80838Fb7C7E6d06Ff9cCe6139CE83D2Dc2d4d7A9;
        financeMultiSigs[84532] = 0x80838Fb7C7E6d06Ff9cCe6139CE83D2Dc2d4d7A9;
        // Polygon zkEVM
        engMultiSigs[1101] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[1101] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
    }

    function getDeployerAddress() internal view returns (address) {
        return deployerAddress;
    }

    /// @notice Check if an environment is valid
    function _validateEnv() private view {
        require(
            keccak256(bytes(env)) == keccak256(bytes("dev-0"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-3"))
                || keccak256(bytes(env)) == keccak256(bytes("test"))
                || keccak256(bytes(env)) == keccak256(bytes("prod")),
            "Invalid environment. Must be 'dev-x', 'test', or 'prod'"
        );
    }

    function isDevEnv() internal view returns (bool) {
        return keccak256(bytes(env)) == keccak256(bytes("dev-0"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-3"));
    }

    function isTestEnv() internal view returns (bool) {
        return keccak256(bytes(env)) == keccak256(bytes("test"));
    }

    function isProdEnv() internal view returns (bool) {
        return keccak256(bytes(env)) == keccak256(bytes("prod"));
    }

    function getEngMultiSig() internal view returns (address) {
        if (isDevEnv()) return getDeployerAddress();
        address addr = engMultiSigs[block.chainid];
        require(addr != address(0), "Eng multi-sig not found");
        return addr;
    }

    function getFinanceMultiSig() internal view returns (address) {
        if (isDevEnv()) return getDeployerAddress();
        address addr = financeMultiSigs[block.chainid];
        require(addr != address(0), "Finance multi-sig not found");
        return addr;
    }
}
