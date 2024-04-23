// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {console2} from "forge-std/Script.sol";
import {
    AirdropNFTCrosschain,
    LagrangeLoonsNFT
} from "../src/client/examples/AirdropNFTCrosschain.sol";
import {LPNQueryV0} from "../src/client/LPNQueryV0.sol";

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

        deployClients();

        registry.toggleWhitelist(toWhitelist);

        if (block.chainid != MAINNET) {
            generateTestnetData();
        }

        assertions();

        // query(
        //     LPNQueryV0(0x80c0a42F808d6f35e83F4939482A485caE536e6a),
        //     0x29469395eAf6f95920E59F858042f0e28D98a20B
        // );
        // withdraw(LPNRegistryV0(0x2584665Beff871534118aAbAE781BC267Af142f9));
        return (registry, impl);
    }

    function query(LPNQueryV0 queryClient, address holder) private {
        uint256 startBlock = 19680500;
        uint256 endBlock = startBlock + 1000;
        uint8 offset = 0;
        queryClient.query{value: 0.05 ether}(
            PUDGEY_PENGUINS, holder, startBlock, endBlock, offset
        );
    }

    function withdraw(LPNRegistryV0 registry_) private {
        registry_.withdrawFees();
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
        if (block.chainid != MAINNET) {
            lloons = new LagrangeLoonsNFT();
            print("LagrangeLoonsNFT", address(lloons));
            client = new AirdropNFTCrosschain(registry, lloons);
            print("AirdropNFTCrosschain", address(client));

            toWhitelist = address(lloons);
        } else {
            LPNQueryV0 queryClient = new LPNQueryV0(registry);
            print("LPNQueryV0", address(queryClient));
        }
    }

    function generateTestnetData() private {
        client.lpnRegister();

        lloons.mint();
        lloons.approve(address(client), 0);
        lloons.mint();
        lloons.transferFrom(deployer, address(client), 0);
    }

    function assertions() private view {}
}
