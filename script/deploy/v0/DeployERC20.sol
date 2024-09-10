// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../../BaseScript.s.sol";
import {LPNRegistryV0} from "../../../src/v0/LPNRegistryV0.sol";
import {TestERC20} from "../../../src/v0/examples/ERC20Balance.sol";

import {
    TEST_ERC20_MAPPING_SLOT,
    isMainnet,
    isEthereum
} from "../../../src/utils/Constants.sol";

contract DeployERC20 is BaseScript {
    struct Deployment {
        address storageContract;
    }

    LPNRegistryV0 registry;
    Deployment deployment;

    /// @notice Deploys + whitelists + registers TestERC20 (only on L1 testnets)
    function run() external broadcaster {
        require(!isMainnet(), "TestERC20 should only be deployed on testnets");
        require(
            isEthereum(), "TestERC20 should only be deployed on L1 testnets"
        );

        registry = LPNRegistryV0(getDeployedRegistry());
        deployment = deploy();

        registry.toggleWhitelist(deployment.storageContract);

        uint256 mappingSlot = TEST_ERC20_MAPPING_SLOT;

        registry.register(deployment.storageContract, mappingSlot, 0);
        generateTestnetData();
    }

    /// @notice Deploys TestERC20 on Anvil, Sepolia, Holesky
    /// @return Deployment address of TestERC20
    function deploy() public returns (Deployment memory) {
        TestERC20 erc20 = new TestERC20();
        print("TestERC20", address(erc20));

        return Deployment({storageContract: address(erc20)});
    }

    /// @notice Mints and transfers tokens
    function generateTestnetData() private {
        TestERC20 erc20 = TestERC20(deployment.storageContract);

        for (uint256 i = 0; i < 20; i++) {
            erc20.mint(deployer, 100_000 ether);
            if (i % 2 == 0) {
                erc20.transfer(getDeployedQueryClient(), 100_000 ether);
            }
        }
    }
}
