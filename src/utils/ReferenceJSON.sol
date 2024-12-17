// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/// @notice This contract is used to read and write to the reference JSON file
abstract contract ReferenceJSON is Script {
    using stdJson for string;

    /// @notice Get the LPN Registry proxy address for a given environment and chain
    /// @param env The environment to get the address for
    /// @param chainName The chain name to get the address for
    /// @return The LPN Registry proxy address
    function getLPNRegistryProxyAddress(
        string memory env,
        string memory chainName
    ) internal view returns (address) {
        string memory json = vm.readFile(outputPath(env, chainName));
        return json.readAddress(".addresses.registryProxy");
    }

    /// @notice Update the LPN Registry implementation address for a given environment and chain
    /// @param env The environment to update the address for
    /// @param chainName The chain name to update the address for
    /// @param newImplAddress The new LPN Registry implementation address
    function updateLPNRegistryImplAddress(
        string memory env,
        string memory chainName,
        address newImplAddress
    ) internal {
        vm.writeJson(
            vm.toString(newImplAddress),
            outputPath(env, chainName),
            ".addresses.registryImpl"
        );
    }

    function outputDir(string memory env, string memory chainName)
        internal
        view
        returns (string memory)
    {
        return string.concat(
            vm.projectRoot(), "/script/output/", env, "/", chainName
        );
    }

    function outputPath(string memory env, string memory chainName)
        internal
        view
        returns (string memory)
    {
        return string.concat(outputDir(env, chainName), "/v1-deployment.json");
    }
}
