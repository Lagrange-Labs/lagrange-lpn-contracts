// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseScript} from "../BaseScript.s.sol";
import {ZKMRStakeRegistry} from "../../src/eigenlayer/ZKMRStakeRegistry.sol";
import {
    Quorum,
    StrategyParams
} from "../../src/eigenlayer/interfaces/IZKMRStakeRegistry.sol";
import {IStrategy} from
    "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ZKMRServiceManager} from "../../src/eigenlayer/ZKMRServiceManager.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {
    PUDGEY_PENGUINS,
    isEthereum,
    isMainnet,
    isLocal
} from "../../src/utils/Constants.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {LibSort} from "solady/utils/LibSort.sol";

contract DeployAVS is BaseScript {
    using stdJson for string;

    address delegationManager = getDelegationManager();
    address avsDirectory = getAvsDirectory();

    struct Deployment {
        ZKMRStakeRegistry stakeRegistryProxy;
        address stakeRegistryImpl;
        ZKMRServiceManager serviceManagerProxy;
        address serviceManagerImpl;
    }

    Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    struct StrategyConfig {
        address addr;
        uint96 multiplier;
        string name;
    }

    function run() external broadcaster returns (Deployment memory) {
        if (getDeployedStakeRegistry() == address(0)) {
            deployment = deploy(deployer);

            deployment.serviceManagerProxy.updateAVSMetadataURI(
                "https://raw.githubusercontent.com/lagrange-labs/lagrange-lpn-contracts/main/config/avs-metadata.json"
            );

            if (isLocal()) {
                string memory key = "WHITELISTED_OPERATORS";
                string memory delimiter = ",";
                address[] memory operators = vm.envAddress(key, delimiter);
                deployment.stakeRegistryProxy.addToWhitelist(operators);
            }

            writeToJson();
        } else {
            address updatedStakeRegistryImpl =
                upgradeStakeRegistry(getDeployedStakeRegistry());

            address updatedServiceManagerImpl =
                upgradeServiceManager(getDeployedServiceManager());

            updateJson(updatedStakeRegistryImpl, updatedServiceManagerImpl);
        }

        return deployment;
    }

    function deploy(address owner) public returns (Deployment memory) {
        // print("quorum", vm.toString(getQuorum().strategies[0].multiplier));
        // Deploy a new implementation
        address stakeRegistryImpl = address(new ZKMRStakeRegistry());
        print("ZKMRStakeRegistry (implementation)", address(stakeRegistryImpl));

        address serviceManagerImpl = address(new ZKMRServiceManager());
        print(
            "ZKMRServiceManager (implementation)", address(serviceManagerImpl)
        );

        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }
        // Deploy a new proxy pointing to the implementation
        // The deployer is the admin of the proxy and is authorized to upgrade the proxy
        // The deployer is the owner of the proxy and is authorized to add whitelisted clients to the stakeRegistry
        address stakeRegistryProxy = proxyFactory.deployDeterministicAndCall(
            stakeRegistryImpl,
            owner,
            newSalt("V0_EUCLID_SR_0"),
            abi.encodeWithSelector(
                ZKMRStakeRegistry.initialize.selector,
                delegationManager,
                getQuorum(),
                owner
            )
        );
        print("ZKMRStakeRegistry (proxy)", address(stakeRegistryProxy));

        address serviceManagerProxy = proxyFactory.deployDeterministicAndCall(
            serviceManagerImpl,
            owner,
            newSalt("V0_EUCLID_SM_0"),
            abi.encodeWithSelector(
                ZKMRServiceManager.initialize.selector,
                avsDirectory,
                stakeRegistryProxy,
                owner
            )
        );
        print("ZKMRServiceManager (proxy)", address(serviceManagerProxy));

        ZKMRStakeRegistry(stakeRegistryProxy).setServiceManager(
            serviceManagerProxy
        );

        return Deployment({
            stakeRegistryProxy: ZKMRStakeRegistry(stakeRegistryProxy),
            stakeRegistryImpl: stakeRegistryImpl,
            serviceManagerProxy: ZKMRServiceManager(serviceManagerProxy),
            serviceManagerImpl: serviceManagerImpl
        });
    }

    function upgradeStakeRegistry(address proxy) public returns (address) {
        address stakeRegistryImpl = address(new ZKMRStakeRegistry());
        print("ZKMRStakeRegistry (implementation)", address(stakeRegistryImpl));

        proxyFactory.upgrade(proxy, stakeRegistryImpl);

        return stakeRegistryImpl;
    }

    function upgradeServiceManager(address proxy) public returns (address) {
        address serviceManagerImpl = address(new ZKMRServiceManager());
        print(
            "ZKMRServiceManager (implementation)", address(serviceManagerImpl)
        );

        proxyFactory.upgrade(proxy, serviceManagerImpl);

        return serviceManagerImpl;
    }

    function getQuorum() private view returns (Quorum memory) {
        string memory json = vm.readFile(avsConfigPath());
        StrategyConfig[] memory strategies;
        bytes memory strategiesRaw = json.parseRaw(".strategies");
        strategies = abi.decode(strategiesRaw, (StrategyConfig[]));

        StrategyParams[] memory strategyParams =
            new StrategyParams[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            strategyParams[i] = StrategyParams({
                strategy: IStrategy(strategies[i].addr),
                multiplier: uint96(strategies[i].multiplier)
            });
        }

        return Quorum({strategies: sortStrategies(strategyParams)});
    }

    function sortStrategies(StrategyParams[] memory strategyParams)
        private
        pure
        returns (StrategyParams[] memory)
    {
        address[] memory addresses = new address[](strategyParams.length);
        for (uint256 i = 0; i < strategyParams.length; i++) {
            addresses[i] = address(strategyParams[i].strategy);
        }

        LibSort.sort(addresses);

        StrategyParams[] memory sortedStrategyParams =
            new StrategyParams[](strategyParams.length);

        for (uint256 i = 0; i < strategyParams.length; i++) {
            for (uint256 j = 0; j < strategyParams.length; j++) {
                if (addresses[i] == address(strategyParams[j].strategy)) {
                    sortedStrategyParams[i] = strategyParams[j];
                    break;
                }
            }
        }
        return sortedStrategyParams;
    }

    function writeToJson() private {
        vm.writeJson(
            vm.toString(address(deployment.stakeRegistryProxy)),
            outputPath(),
            ".addresses.stakeRegistryProxy"
        );
        vm.writeJson(
            vm.toString(deployment.stakeRegistryImpl),
            outputPath(),
            ".addresses.stakeRegistryImpl"
        );

        vm.writeJson(
            vm.toString(address(deployment.serviceManagerProxy)),
            outputPath(),
            ".addresses.serviceManagerProxy"
        );
        vm.writeJson(
            vm.toString(deployment.serviceManagerImpl),
            outputPath(),
            ".addresses.serviceManagerImpl"
        );
    }

    function updateJson(address stakeRegistryImpl, address serviceManagerImpl)
        private
    {
        vm.writeJson(
            vm.toString(address(stakeRegistryImpl)),
            outputPath(),
            ".addresses.stakeRegistryImpl"
        );

        vm.writeJson(
            vm.toString(address(serviceManagerImpl)),
            outputPath(),
            ".addresses.serviceManagerImpl"
        );
    }
}
