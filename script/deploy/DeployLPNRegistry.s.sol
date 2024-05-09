// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV0} from "../../src/LPNRegistryV0.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {
    PUDGEY_PENGUINS,
    isEthereum,
    isMainnet,
    isLocal
} from "../../src/utils/Constants.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract DeployLPNRegistry is BaseScript {
    using stdJson for string;

    struct Deployment {
        LPNRegistryV0 registryProxy;
        address registryImpl;
    }

    Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    function run() external broadcaster returns (Deployment memory) {
        if (getDeployedRegistry() == address(0)) {
            deployment = deploy(salt, deployer);
            writeToJson();
        } else {
            address updatedRegistryImpl = upgrade(getDeployedRegistry());
            writeToJson(updatedRegistryImpl);
        }

        assertions();

        return deployment;
    }

    function deploy(bytes32 salt_, address owner)
        public
        returns (Deployment memory)
    {
        // Deploy a new implementation
        address registryImpl = address(new LPNRegistryV0());
        print("LPNRegistryV0 (implementation)", address(registryImpl));

        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }
        // Deploy a new proxy pointing to the implementation
        // The deployer is the admin of the proxy and is authorized to upgrade the proxy
        // The deployer is the owner of the proxy and is authorized to add whitelisted clients to the registry
        address registryProxy = proxyFactory.deployDeterministicAndCall(
            registryImpl,
            owner,
            salt_,
            abi.encodeWithSelector(LPNRegistryV0.initialize.selector, owner)
        );
        print("LPNRegistryV0 (proxy)", address(registryProxy));

        return Deployment({
            registryProxy: LPNRegistryV0(registryProxy),
            registryImpl: registryImpl
        });
    }

    function upgrade(address proxy) public returns (address) {
        // Deploy a new implementation
        address registryImpl = address(new LPNRegistryV0());
        print("LPNRegistryV0 (implementation)", address(registryImpl));

        // Update proxy to point to new implementation contract
        proxyFactory.upgrade(proxy, registryImpl);
        return registryImpl;
    }

    function assertions() private view {}

    function writeToJson() private {
        mkdir(outputDir());

        string memory json = "deploymentArtifact";

        string memory addresses = "addresses";
        addresses.serialize("storageContract", address(0));
        addresses.serialize("queryClient", address(0));
        addresses.serialize("registryImpl", deployment.registryImpl);
        addresses = addresses.serialize(
            "registryProxy", address(deployment.registryProxy)
        );

        string memory chainInfo = "chainInfo";
        chainInfo.serialize("chainId", block.chainid);
        chainInfo = chainInfo.serialize("deploymentBlock", block.number);

        json.serialize("addresses", addresses);
        json = json.serialize("chainInfo", chainInfo);

        json.write(outputPath());
    }

    function writeToJson(address updatedRegistryImpl) private {
        vm.writeJson(
            vm.toString(updatedRegistryImpl),
            outputPath(),
            ".addresses.registryImpl"
        );
    }
}
