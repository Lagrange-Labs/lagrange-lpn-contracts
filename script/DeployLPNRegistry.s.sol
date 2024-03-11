// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";

contract DeployLPNRegistry is BaseScript {
    LPNRegistryV0 registry;
    address impl;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    function run() external returns (LPNRegistryV0, address) {
        (registry, impl) = deploy(salt);
        assertions();
        return (registry, impl);
    }

    function deploy(bytes32 salt_)
        public
        broadcaster
        returns (LPNRegistryV0, address)
    {
        // Deploy a new implementation
        address registryImpl = address(new LPNRegistryV0());
        print("LPNRegistryV0 (implementation)", address(registryImpl));

        // Deploy a new proxy pointing to the implementation
        // The deployer is the admin of the proxy and is authorized to upgrade the proxy
        // The deployer is the owner of the proxy and is authorized to add whitelisted clients to the registry
        address registryProxy = proxyFactory.deployDeterministicAndCall(
            registryImpl,
            deployer,
            salt_,
            abi.encodeWithSelector(LPNRegistryV0.initialize.selector, deployer)
        );
        print("LPNRegistryV0 (proxy)", address(registryProxy));

        return (LPNRegistryV0(registryProxy), registryImpl);
    }

    function upgrade(address proxy) public broadcaster returns (address) {
        // Deploy a new implementation
        address registryImpl = address(new LPNRegistryV0());
        print("LPNRegistryV0 (implementation)", address(registryImpl));

        // Update proxy to point to new implementation contract
        proxyFactory.upgrade(proxy, registryImpl);
        return registryImpl;
    }

    function assertions() private view {}
}
