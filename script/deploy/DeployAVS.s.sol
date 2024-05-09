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
        uint96 multiplier;
        address addr;
        string name;
    }

    function run() external broadcaster returns (Deployment memory) {
        if (getDeployedStakeRegistry() == address(0)) {
            deployment = deploy(salt, deployer);

            deployment.serviceManagerProxy.updateAVSMetadataURI(
                "https://raw.githubusercontent.com/lagrange-labs/lagrange-lpn-contracts/main/config/avs-metadata.json"
            );

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

    function deploy(bytes32 salt_, address owner)
        public
        returns (Deployment memory)
    {
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
            salt_,
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
            salt_,
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
        bytes memory strategiesRaw = stdJson.parseRaw(json, ".strategies");
        strategies = abi.decode(strategiesRaw, (StrategyConfig[]));

        StrategyParams[] memory strategyParams;
        for (uint256 i = 0; i < strategies.length; i++) {
            strategyParams[i] = StrategyParams({
                strategy: IStrategy(strategies[i].addr),
                multiplier: strategies[i].multiplier
            });
        }

        return Quorum({strategies: strategyParams});
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
