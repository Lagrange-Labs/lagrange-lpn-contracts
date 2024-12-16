// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/// @notice This contract defines the chains that are configured for each environment
abstract contract Environments {
    mapping(string => string[]) private chainsByEnv;

    constructor() {
        // Dev environment chains
        chainsByEnv["dev-0"] = ["holesky"];
        chainsByEnv["dev-1"] = ["holesky"];
        chainsByEnv["dev-3"] = ["holesky"];

        // Test environment chains
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

    modifier validEnv(string memory env) {
        require(
            keccak256(bytes(env)) == keccak256(bytes("dev-0"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-3"))
                || keccak256(bytes(env)) == keccak256(bytes("test"))
                || keccak256(bytes(env)) == keccak256(bytes("prod")),
            "Invalid environment. Must be 'dev-x', 'test', or 'prod'"
        );
        _;
    }

    /// @notice Get the chains that are configured for a given environment
    /// @param env The environment to get chains for
    /// @return chains the list of chain names that are configured for the given environment
    function getChainsForEnv(string memory env)
        internal
        view
        returns (string[] memory)
    {
        return chainsByEnv[env];
    }
}
