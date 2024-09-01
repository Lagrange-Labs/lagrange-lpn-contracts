// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV1} from "../../src/v1/LPNRegistryV1.sol";
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
        LPNRegistryV1 registryProxy;
        address registryImpl;
    }

    Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    function run() external broadcaster returns (Deployment memory) {
        if (getDeployedRegistry(Version.V1) == address(0)) {
            deployment = deploy(newSalt("V1_REG_0"), deployer);
            writeToJson();
        } else {
            address updatedRegistryImpl =
                upgrade(getDeployedRegistry(Version.V1));
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
        address registryImpl = address(new LPNRegistryV1());
        print("LPNRegistryV1 (implementation)", address(registryImpl));

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
            abi.encodeWithSelector(LPNRegistryV1.initialize.selector, owner)
        );
        print("LPNRegistryV1 (proxy)", address(registryProxy));

        return Deployment({
            registryProxy: LPNRegistryV1(registryProxy),
            registryImpl: registryImpl
        });
    }

    function upgrade(address proxy) public returns (address) {
        // Deploy a new implementation
        address registryImpl = address(new LPNRegistryV1());
        print("LPNRegistryV1 (implementation)", address(registryImpl));

        // Update proxy to point to new implementation contract
        proxyFactory.upgrade(proxy, registryImpl);
        return registryImpl;
    }

    function assertions() private view {}

    function writeToJson() private {
        mkdir(outputDir());

        string memory json = "deploymentArtifact";

        string memory addresses = "addresses";
        addresses.serialize("queryClient", address(0));
        addresses.serialize("registryImpl", deployment.registryImpl);
        addresses = addresses.serialize(
            "registryProxy", address(deployment.registryProxy)
        );

        string memory storageContracts = "storageContracts";
        storageContracts.serialize("erc721Enumerable", address(0));
        storageContracts.serialize("erc20ProportionateBalance", address(0));
        storageContracts =
            storageContracts.serialize("erc20AvgBalance", address(0));

        string memory chainInfo = "chainInfo";
        chainInfo.serialize("chainId", block.chainid);
        chainInfo = chainInfo.serialize("deploymentBlock", block.number);

        json.serialize("addresses", addresses);
        json.serialize("storageContracts", storageContracts);
        json = json.serialize("chainInfo", chainInfo);

        json.write(outputPath(Version.V1));
    }

    function writeToJson(address updatedRegistryImpl) private {
        vm.writeJson(
            vm.toString(updatedRegistryImpl),
            outputPath(Version.V1),
            ".addresses.registryImpl"
        );
    }
}
