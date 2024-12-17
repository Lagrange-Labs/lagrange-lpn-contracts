// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {console2 as console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {LPNQueryV1} from "../src/v1/client/LPNQueryV1.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Script} from "forge-std/Script.sol";
import {ChainConnections} from "../src/utils/ChainConnections.sol";
import {Environments} from "../src/utils/Environments.sol";

contract VerifyV1Deployments is Script, ChainConnections, Environments {
    using stdJson for string;
    using LibString for string;

    bytes32 constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /// @notice entrypoint for the script; verifies the arrangement of all deployed v1 contracts
    function run() public {
        execute(false);
    }

    /// @notice alternative entrypoint for the script; verifies the arrangement of all deployed v1 contracts
    /// and attempts to fix any misaligned json files
    function fix() public {
        execute(true);
    }

    /// @param shouldFix if true, will attempt to fix the misaligned json files
    /// @dev this script does change anything about the deployed contracts; it sends no transactions;
    /// it only verifies the correctness of the local json files
    function execute(bool shouldFix) internal {
        // Find all v1-deployment.json files
        string[] memory shellCommandInputs = new string[](3);
        shellCommandInputs[0] = "/bin/sh";
        shellCommandInputs[1] = "-c";
        shellCommandInputs[2] = "find . -name v1-deployment.json | sort";
        bytes memory output = vm.ffi(shellCommandInputs);
        string[] memory files = string(output).split("\n");

        // we only fail at the end of the script to ensure all chains are checked
        bool shouldFail;

        for (uint256 i = 0; i < files.length; i++) {
            string memory jsonStr = vm.readFile(files[i]);

            // Extract chain ID and switch RPC
            uint256 chainId =
                abi.decode(jsonStr.parseRaw(".chainInfo.chainId"), (uint256));
            vm.createSelectFork(getChain(chainId).rpcUrl);

            // Extract addresses
            address queryClientProxy = abi.decode(
                jsonStr.parseRaw(".addresses.queryClientProxy"), (address)
            );
            address queryClientImpl = abi.decode(
                jsonStr.parseRaw(".addresses.queryClientImpl"), (address)
            );
            address registryProxy = abi.decode(
                jsonStr.parseRaw(".addresses.registryProxy"), (address)
            );
            address registryImpl = abi.decode(
                jsonStr.parseRaw(".addresses.registryImpl"), (address)
            );

            // Print deployment info
            console.log("\nVerifying deployment in file:", files[i]);
            console.log("Chain ID:", chainId);
            console.log("QueryClient Proxy:", queryClientProxy);
            console.log("QueryClient Implementation:", queryClientImpl);
            console.log("Registry Proxy:", registryProxy);
            console.log("Registry Implementation:", registryImpl);
            console.log(
                "--------------------- Assertions ---------------------"
            );

            // Verify query client proxy implementation
            if (queryClientProxy != address(0)) {
                address actualQueryImpl =
                    getProxyImplementation(queryClientProxy);
                if (actualQueryImpl != queryClientImpl) {
                    shouldFail = true;
                    console.log(
                        unicode"✗ QueryClient Proxy points to incorrect implementation"
                    );
                    if (shouldFix) {
                        jsonStr = vm.serializeString(
                            jsonStr,
                            ".addresses.queryClientImpl",
                            vm.toString(actualQueryImpl)
                        );
                    }
                } else {
                    console.log(
                        unicode"✓ QueryClient Proxy points to correct implementation"
                    );
                }
            } else {
                console.log(
                    unicode"✓ QueryClient Proxy not deployed, skipping check"
                );
            }

            // Verify query client points to the correct registry
            if (queryClientProxy != address(0)) {
                address linkedRegistry =
                    address(LPNQueryV1(queryClientProxy).lpnRegistry());
                if (linkedRegistry != registryProxy) {
                    shouldFail = true;
                    console.log(
                        unicode"✗ QueryClient points to incorrect LPNRegistry"
                    );
                } else {
                    console.log(
                        unicode"✓ QueryClient points to correct LPNRegistry"
                    );
                }
            } else {
                console.log(
                    unicode"✓ QueryClient Proxy not deployed, skipping check"
                );
            }

            // Verify registry proxy implementation
            if (registryProxy != address(0)) {
                address actualRegistryImpl =
                    getProxyImplementation(registryProxy);
                if (actualRegistryImpl != registryImpl) {
                    shouldFail = true;
                    console.log(
                        unicode"✗ Registry Proxy points to incorrect implementation"
                    );
                    if (shouldFix) {
                        jsonStr = vm.serializeString(
                            jsonStr,
                            ".addresses.registryImpl",
                            vm.toString(actualRegistryImpl)
                        );
                    }
                } else {
                    console.log(
                        unicode"✓ Registry proxy points to correct implementation"
                    );
                }
            } else {
                console.log(
                    unicode"✓ Registry proxy not deployed, skipping check"
                );
            }

            vm.writeJson(jsonStr, files[i]);
        }

        if (shouldFail) revert("verification failed");
    }

    function getProxyImplementation(address proxy)
        internal
        view
        returns (address)
    {
        address implementation;
        bytes32 result = vm.load(proxy, IMPLEMENTATION_SLOT);
        assembly {
            implementation := result
        }
        return implementation;
    }
}
