// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

abstract contract ReferenceJSON is Script {
    using stdJson for string;

    function getLPNRegistryProxyAddress(string memory chainName)
        internal
        view
        returns (address)
    {
        string memory json = vm.readFile(outputPath(chainName));
        return json.readAddress(".addresses.registryProxy");
    }

    function updateLPNRegistryImplAddress(
        string memory chainName,
        address newImplAddress
    ) internal {
        vm.writeJson(
            vm.toString(newImplAddress),
            outputPath(chainName),
            ".addresses.registryImpl"
        );
    }

    function outputDir(string memory chainName)
        internal
        view
        returns (string memory)
    {
        return string.concat(vm.projectRoot(), "/script/output/", chainName);
    }

    function outputPath(string memory chainName)
        internal
        view
        returns (string memory)
    {
        return string.concat(outputDir(chainName), "/v1-deployment.json");
    }
}
