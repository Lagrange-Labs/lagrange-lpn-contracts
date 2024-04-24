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
    PUDGEY_PENGUINS_MAPPING_SLOT,
    PUDGEY_PENGUINS_LENGTH_SLOT,
    LAGRANGE_LOONS_MAPPING_SLOT,
    LAGRANGE_LOONS_LENGTH_SLOT,
    isMainnet,
    isTestnet,
    isLocal
} from "../../src/utils/Constants.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract DeployClients is BaseScript {
    using stdJson for string;

    struct Deployment {
        address queryClient;
        address storageContract;
    }

    LPNRegistryV0 registry;
    Deployment deployment;

    function run() external broadcaster {
        registry = LPNRegistryV0(getDeployedRegistry());
        deployment = deploy();

        if (!registry.whitelist(deployment.storageContract)) {
            registry.toggleWhitelist(deployment.storageContract);
        }

        uint256 mappingSlot;
        uint256 lengthSlot;

        if (isMainnet()) {
            mappingSlot = PUDGEY_PENGUINS_MAPPING_SLOT;
            lengthSlot = PUDGEY_PENGUINS_LENGTH_SLOT;
        } else {
            mappingSlot = LAGRANGE_LOONS_MAPPING_SLOT;
            lengthSlot = LAGRANGE_LOONS_LENGTH_SLOT;
        }

        registry.register(deployment.storageContract, mappingSlot, lengthSlot);

        if (isTestnet() || isLocal()) {
            generateTestnetData();
        }

        assertions();

        writeToJson();
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
        LagrangeLoonsNFT lloons = LagrangeLoonsNFT(deployment.storageContract);

        lloons.mint();
        lloons.approve(deployment.queryClient, 0);
        lloons.mint();
        lloons.transferFrom(deployer, deployment.queryClient, 0);
    }

    function writeToJson() private {
        vm.writeJson(
            vm.toString(deployment.storageContract),
            outputPath(),
            ".addresses.storageContract"
        );

        vm.writeJson(
            vm.toString(deployment.queryClient),
            outputPath(),
            ".addresses.queryClient"
        );
    }

    function assertions() private view {}
}
