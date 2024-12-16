// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseDeployer} from "../BaseDeployer.s.sol";
import {LPNRegistryV1} from "../../src/v1/LPNRegistryV1.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {isMainnet, isLocal} from "../../src/utils/Constants.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract DeployLPNRegistryV1 is BaseDeployer {
    using stdJson for string;

    struct Deployment {
        LPNRegistryV1 registryProxy;
        address registryImpl;
    }

    Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    function run() external returns (Deployment memory) {
        if (getDeployedRegistry() == address(0)) {
            deployment.registryImpl = deployImplementation();

            address owner = isMainnet() ? address(SAFE) : deployer;

            bytes32 salt = newSalt(vm.envString("SALT"));

            deployment.registryProxy =
                LPNRegistryV1(deployProxy(deployment.registryImpl, salt, owner));

            writeToJson();
        } else {
            deployment.registryImpl = deployImplementation();
            upgrade(
                LPNRegistryV1(getDeployedRegistry()), deployment.registryImpl
            );

            writeToJson(deployment.registryImpl);
        }

        return deployment;
    }

    /// @dev Deploy a new implementation contract
    function deployImplementation() public broadcaster returns (address) {
        address registryImpl = address(new LPNRegistryV1());
        print("LPNRegistryV1 (implementation)", address(registryImpl));
        return registryImpl;
    }

    /// @dev Deploy a new proxy pointing to the implementation
    /// @dev The deployer is the admin of the proxy and is authorized to upgrade the proxy
    /// @dev The deployer is the owner of the proxy and is authorized to add whitelisted clients to the registry
    function deployProxy(address registryImpl, bytes32 salt_, address owner)
        public
        broadcaster
        returns (address)
    {
        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }
        address registryProxy = proxyFactory.deployDeterministicAndCall(
            registryImpl,
            owner,
            salt_,
            abi.encodeWithSelector(LPNRegistryV1.initialize.selector, owner)
        );

        print("LPNRegistryV1 (proxy)", registryProxy);

        return registryProxy;
    }

    /// @dev Update proxy to point to new implementation contract
    /// @dev On mainnets, this proposes a tx to the multisig
    /// @dev On testnets, this directly sends a tx onchain
    function upgrade(LPNRegistryV1 proxy, address registryImpl) public {
        if (isMainnet()) {
            upgradeMainnet(proxy, registryImpl);
        } else {
            upgradeHolesky(proxy, registryImpl);
        }
    }

    function upgradeMainnet(LPNRegistryV1 proxy, address registryImpl)
        public
        isBatch(address(SAFE))
    {
        bytes memory txn = abi.encodeWithSelector(
            ERC1967Factory.upgrade.selector, address(proxy), registryImpl
        );

        addToBatch(address(proxyFactory), txn);
        executeBatch(true);
    }

    function upgradeHolesky(LPNRegistryV1 proxy, address registryImpl)
        public
        broadcaster
    {
        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }

        proxyFactory.upgrade(address(proxy), registryImpl);
    }

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
