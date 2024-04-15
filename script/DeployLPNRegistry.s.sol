// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {console2} from "forge-std/Script.sol";
import "../src/client/examples/AirdropNFTCrosschain.sol";

contract DeployLPNRegistry is BaseScript {
    LPNRegistryV0 registry;
    address impl;
    AirdropNFTCrosschain client;
    LagrangeLoonsNFT lloons;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    address PUDGEY_PENGUINS = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;
    address toWhitelist = PUDGEY_PENGUINS;

    function run() external broadcaster returns (LPNRegistryV0, address) {
        (registry, impl) = deploy(salt);

        if (block.chainid != MAINNET) {
            deployClients();
        }

        registry.toggleWhitelist(toWhitelist);

        if (block.chainid != MAINNET) {
            generateTestnetData();
        }

        assertions();
        return (registry, impl);
    }

    function deploy(bytes32 salt_) public returns (LPNRegistryV0, address) {
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

    function deployClients() private {
        lloons = new LagrangeLoonsNFT();
        print("LagrangeLoonsNFT", address(lloons));
        client = new AirdropNFTCrosschain(registry, lloons);
        print("AirdropNFTCrosschain", address(client));

        toWhitelist = address(lloons);
    }

    function generateTestnetData() private {
        client.lpnRegister();

        lloons.mint();
        lloons.approve(address(client), 0);
        lloons.mint();
        lloons.transferFrom(deployer, address(client), 0);
        // client.queryHolder{value: registry.GAS_FEE()}(deployer);
    }

    function assertions() private view {}
}
