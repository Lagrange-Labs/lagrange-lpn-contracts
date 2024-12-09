// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console2 as console} from "forge-std/Script.sol";

/// @dev Script to check the balance of the deployment key on all configured chains
contract CheckDeploymentKeyBalances is Script {
    // Address to check balances for
    address constant DEPLOYER_ADDRESS =
        0x48211415Fc3e48b1aC5389fdDD4c1755783F6199;

    // Minimum balance to check for
    uint256 constant MIN_BALANCE = 1 ether;

    mapping(string => string[]) internal chainsByEnv;

    constructor() {
        // Dev environment deloyments
        chainsByEnv["dev-0"] = ["holesky"];
        chainsByEnv["dev-1"] = ["holesky"];
        chainsByEnv["dev-3"] = ["holesky"];

        // Test environment deplolyments
        chainsByEnv["test"] = [
            "sepolia",
            "holesky",
            "base_sepolia",
            "mantle_sepolia",
            "scroll_sepolia",
            "fraxtal_testnet"
        ];

        // Prod environment chains
        chainsByEnv["prod"] =
            ["mainnet", "base", "mantle", "polygon_zkevm", "scroll", "fraxtal"];
    }

    /// @param env The environment to check balances for
    function run(string calldata env) external {
        require(
            keccak256(bytes(env)) == keccak256(bytes("dev-0"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-3"))
                || keccak256(bytes(env)) == keccak256(bytes("test"))
                || keccak256(bytes(env)) == keccak256(bytes("prod")),
            "Invalid environment. Must be 'dev-x', 'test', or 'prod'"
        );

        string[] memory chains = chainsByEnv[env];

        console.log("\nChecking balances for environment:", env);
        console.log("");
        console.log("Address:", DEPLOYER_ADDRESS);
        console.log("Minimum balance:", MIN_BALANCE, "WEI");
        console.log("----------------------------------------");

        bool success = true;
        bool erorrsEncountered;

        for (uint256 i = 0; i < chains.length; i++) {
            string memory chain = chains[i];

            string memory status;
            string memory balanceString;

            try this.switchChain(chain) {
                uint256 balance = DEPLOYER_ADDRESS.balance;
                status = balance >= MIN_BALANCE ? "OK" : "LOW";
                balanceString = string.concat(
                    " (",
                    vm.toString(balance / 1 ether),
                    ".",
                    vm.toString(((balance % 1 ether) * 1000) / 1 ether), // add 3 decimals
                    " ETH)"
                );
            } catch {
                erorrsEncountered = true;
                status = "ERROR";
            }

            console.log(string.concat(chain, ": ", status, balanceString));

            success =
                success && (keccak256(bytes(status)) == keccak256(bytes("OK")));
        }

        console.log("");

        if (erorrsEncountered) {
            console.log(
                "ERROR: not all balances could be retrieved, check that RPCs are provided for all chains in the given environment"
            );
            console.log(
                "REFERENCE: https://book.getfoundry.sh/reference/config/testing#rpc_endpoints\n"
            );
        }

        if (!success) {
            revert("Failed");
        }
    }

    /// @dev we call this function using this.switchChain() so that errors can be
    /// rescued and the script can continue running
    function switchChain(string calldata chain) public {
        vm.createSelectFork(chain);
    }
}
