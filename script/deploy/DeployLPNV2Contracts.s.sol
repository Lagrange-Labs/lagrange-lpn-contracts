// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    getProxyImplementation, getProxyAdmin
} from "../../src/utils/Proxy.sol";
import {Deployer} from "../../src/v2/Deployer.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeploymentUtils} from "../../src/utils/DeploymentUtils.sol";

/// @notice Script to deploy and configure LPN V2 contracts
/// @dev Reads private key & multisig addresses from environment variables
/// @dev uses Deployer contract to deploy and configure the V2 contracts in a single transaction
contract DeployLPNV2Contracts is DeploymentUtils {
    /// @notice Deploys V2 contracts
    function run() external {
        console.log(unicode"🚀 Deploying V2 contracts");

        vm.startBroadcast();
        vm.recordLogs();

        // Deploy all V2 contracts using the Deployer contract
        new Deployer(getEngMultiSig(), getFinanceMultiSig());

        // Capture emitted events from the Deployer to get contract addresses
        vm.stopBroadcast();

        // Get the ContractsDeployed event (should always be the last one)
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory lastEntry = entries[entries.length - 1];
        require(
            lastEntry.topics[0] == Deployer.ContractsDeployed.selector,
            "could not find ContractsDeployed event"
        );

        // Parse emitted addresses from event
        (
            address routerProxy,
            address dbManagerProxy,
            address feeCollector,
            address queryExecutor,
            address lpnClientExample
        ) = abi.decode(
            lastEntry.data, (address, address, address, address, address)
        );

        // Get implementation and admin addresses from proxies
        address routerImpl = getProxyImplementation(routerProxy);
        address dbManagerImpl = getProxyImplementation(dbManagerProxy);
        address routerProxyAdmin = getProxyAdmin(routerProxy);
        address dbManagerProxyAdmin = getProxyAdmin(dbManagerProxy);

        console.log(unicode"✅ V2 contracts deployed successfully");
        console.log("Router Proxy: %s", routerProxy);
        console.log("Router Implementation: %s", routerImpl);
        console.log("Router Proxy Admin: %s", routerProxyAdmin);
        console.log("DB Manager Proxy: %s", dbManagerProxy);
        console.log("DB Manager Implementation: %s", dbManagerImpl);
        console.log("DB Manager Proxy Admin: %s", dbManagerProxyAdmin);
        console.log("Fee Collector: %s", feeCollector);
        console.log("Query Executor: %s", queryExecutor);
        console.log("LPN Client Example: %s", lpnClientExample);
    }
}
