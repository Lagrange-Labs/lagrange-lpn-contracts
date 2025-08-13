// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {getProxyImplementation, getProxyAdmin} from "../utils/Proxy.sol";
import {Deployer} from "../../src/v2/Deployer.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeploymentUtils} from "../utils/DeploymentUtils.sol";

/// @notice Script to deploy and configure LPN V2 contracts
/// @dev Reads private key & multisig addresses from environment variables
/// @dev uses Deployer contract to deploy and configure the V2 contracts in a single transaction
contract DeployLPNV2Contracts is DeploymentUtils {
    /// @dev Struct to store the deployment addresses, relieves stack pressure
    struct Deployment {
        address routerProxy;
        address routerImplementation;
        address routerProxyAdmin;
        address dbManagerProxy;
        address dbManagerImplementation;
        address dbManagerProxyAdmin;
        address feeCollector;
        address queryExecutor;
        address lpnClientExample;
    }

    /// @notice Deploys V2 contracts
    function run() external {
        checkVerifier();

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

        Deployment memory deployment;
        // Parse emitted addresses from event
        (
            deployment.routerProxy,
            deployment.dbManagerProxy,
            deployment.feeCollector,
            deployment.queryExecutor,
            deployment.lpnClientExample
        ) = abi.decode(
            lastEntry.data, (address, address, address, address, address)
        );

        // Get implementation and admin addresses from proxies
        deployment.routerImplementation =
            getProxyImplementation(deployment.routerProxy);
        deployment.dbManagerImplementation =
            getProxyImplementation(deployment.dbManagerProxy);
        deployment.routerProxyAdmin = getProxyAdmin(deployment.routerProxy);
        deployment.dbManagerProxyAdmin =
            getProxyAdmin(deployment.dbManagerProxy);

        console.log(unicode"✅ V2 contracts deployed successfully");
        console.log("Router Proxy: %s", deployment.routerProxy);
        console.log(
            "Router Implementation: %s", deployment.routerImplementation
        );
        console.log("Router Proxy Admin: %s", deployment.routerProxyAdmin);
        console.log("DB Manager Proxy: %s", deployment.dbManagerProxy);
        console.log(
            "DB Manager Implementation: %s", deployment.dbManagerImplementation
        );
        console.log(
            "DB Manager Proxy Admin: %s", deployment.dbManagerProxyAdmin
        );
        console.log("Fee Collector: %s", deployment.feeCollector);
        console.log("Query Executor: %s", deployment.queryExecutor);
        console.log("LPN Client Example: %s", deployment.lpnClientExample);

        // Write contract addresses to a deployment json file
        string memory outputDir =
            string.concat("script/output/", getChainName());
        vm.createDir(outputDir, true);
        string memory filePath =
            string.concat(outputDir, "/coprocessor-v2-deployment.json");
        vm.writeFile(
            filePath,
            string(
                abi.encodePacked(
                    "{\n",
                    '  "routerProxy": "',
                    vm.toString(deployment.routerProxy),
                    '",\n',
                    '  "routerImplementation": "',
                    vm.toString(deployment.routerImplementation),
                    '",\n',
                    '  "dbManagerProxy": "',
                    vm.toString(deployment.dbManagerProxy),
                    '",\n',
                    '  "dbManagerImplementation": "',
                    vm.toString(deployment.dbManagerImplementation),
                    '",\n',
                    '  "feeCollector": "',
                    vm.toString(deployment.feeCollector),
                    '",\n',
                    '  "queryExecutor": "',
                    vm.toString(deployment.queryExecutor),
                    '",\n',
                    '  "lpnClientExample": "',
                    vm.toString(deployment.lpnClientExample),
                    '"\n',
                    "}"
                )
            )
        );
        console.log(
            string.concat(unicode"📝 Deployment addresses written to ", filePath)
        );
    }
}
