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
    isEthereum,
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

    /// @notice Deploys LPNQueryV0 and LagrangeLoonsNFT (only on Sepolia); whitelists and registers storageContract on L1
    function run() external broadcaster {
        if (isTestnet() || isLocal()) {
            deployment.storageContract = deployTestNFT();
            address receiver = 0x000000000000000000000000000000000000dEaD;
            generateTestnetData(receiver);
        }

        // registry = LPNRegistryV0(getDeployedRegistry());
        // deployment = deploy();
        //
        // if (isEthereum() && !registry.whitelist(deployment.storageContract)) {
        //     registry.toggleWhitelist(deployment.storageContract);
        // }
        //
        // uint256 mappingSlot;
        // uint256 lengthSlot;
        //
        // if (isMainnet()) {
        //     mappingSlot = PUDGEY_PENGUINS_MAPPING_SLOT;
        //     lengthSlot = PUDGEY_PENGUINS_LENGTH_SLOT;
        // } else {
        //     mappingSlot = LAGRANGE_LOONS_MAPPING_SLOT;
        //     lengthSlot = LAGRANGE_LOONS_LENGTH_SLOT;
        // }
        //
        // if (isEthereum()) {
        //     registry.register(
        //         deployment.storageContract, mappingSlot, lengthSlot
        //     );
        // }
        //
        // if (isEthereum() && (isTestnet() || isLocal())) {
        //     generateTestnetData();
        // }
        //
        // assertions();
        //
        // writeToJson();
    }

    /// @notice Deploys LPNQueryV0 on all chains; Deploys LagrangeLoonsNFT on Sepolia
    /// @return Deployment addresses of deployed contracts; address(0) if storageContract is skipped
    function deploy() public returns (Deployment memory) {
        // TODO: Use an upgradeable proxy next time the query client changes
        address queryClient =
            address(new LPNQueryV0{salt: "LPNQueryV0_1"}(registry));
        print("LPNQueryV0", queryClient);

        if (isMainnet()) {
            return Deployment({
                storageContract: getDeployedStorageContract("erc721Enumerable"),
                queryClient: queryClient
            });
        }

        if (isTestnet() || isLocal()) {
            LagrangeLoonsNFT lloons;

            if (isEthereum()) {
                lloons = new LagrangeLoonsNFT();
                print("LagrangeLoonsNFT", address(lloons));
            }

            return Deployment({
                storageContract: address(lloons),
                queryClient: queryClient
            });
        }

        revert("Unregistered Chain");
    }

    /// @notice Deploys LagrangeLoonsNFT on Testnets and Local
    /// @return address of deployed contract
    function deployTestNFT() public returns (address) {
        LagrangeLoonsNFT lloons;

        if (isEthereum()) {
            lloons = new LagrangeLoonsNFT();
            print("LagrangeLoonsNFT", address(lloons));
        }

        return address(lloons);
    }

    /// @notice Mints and transfers NFTs
    function generateTestnetData(address receiver) private {
        LagrangeLoonsNFT lloons = LagrangeLoonsNFT(deployment.storageContract);
        if (!lloons.isApprovedForAll(deployer, receiver)) {
            lloons.setApprovalForAll(receiver, true);
        }

        for (uint256 i = 0; i < 20; i++) {
            lloons.mint();
            if (i % 2 == 0) {
                lloons.transferFrom(deployer, receiver, i);
            }
        }
    }

    /// @notice Writes deployed contract addresses to script/output/<chain>/deployments.json
    function writeToJson() private {
        vm.writeJson(
            vm.toString(deployment.storageContract),
            outputPath(),
            ".addresses.storageContract.erc721Enumerable"
        );

        vm.writeJson(
            vm.toString(deployment.queryClient),
            outputPath(),
            ".addresses.queryClient"
        );
    }

    function assertions() private view {}
}
