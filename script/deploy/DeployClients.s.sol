// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV0} from "../../src/LPNRegistryV0.sol";
import {
    AirdropNFTCrosschain,
    LagrangeLoonsNFT
} from "../../src/client/examples/AirdropNFTCrosschain.sol";
import {LPNQueryV0} from "../../src/client/LPNQueryV0.sol";
import {
    PUDGEY_PENGUINS,
    isMainnet,
    isTestnet,
    isLocal
} from "../../src/utils/Constants.sol";

contract DeployClients is BaseScript {
    struct Deployment {
        address queryClient;
        address storageContract;
    }

    LPNRegistryV0 registry;
    Deployment deployment;

    function run() external broadcaster {
        deployment = deploy();

        if (!registry.whitelist(deployment.storageContract)) {
            registry.toggleWhitelist(deployment.storageContract);
        }

        if (isTestnet() || isLocal()) {
            generateTestnetData();
        }

        assertions();
    }

    function deploy() public returns (Deployment memory) {
        if (isTestnet() || isLocal()) {
            LagrangeLoonsNFT lloons = new LagrangeLoonsNFT();
            print("LagrangeLoonsNFT", address(lloons));

            AirdropNFTCrosschain client =
                new AirdropNFTCrosschain(registry, lloons);

            print("AirdropNFTCrosschain", address(client));

            return Deployment({
                storageContract: address(lloons),
                queryClient: address(client)
            });
        }

        if (isMainnet()) {
            address client = address(new LPNQueryV0(registry));
            print("LPNQueryV0", client);
            return Deployment({
                storageContract: PUDGEY_PENGUINS,
                queryClient: client
            });
        }

        revert("Unregistered Chain");
    }

    function generateTestnetData() private {
        AirdropNFTCrosschain client =
            AirdropNFTCrosschain(deployment.queryClient);
        LagrangeLoonsNFT lloons = LagrangeLoonsNFT(deployment.storageContract);

        client.lpnRegister();
        lloons.mint();
        lloons.approve(address(client), 0);
        lloons.mint();
        lloons.transferFrom(deployer, address(client), 0);
    }

    function assertions() private view {}
}
