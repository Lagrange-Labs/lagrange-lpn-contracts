// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseDeployer} from "../BaseDeployer.s.sol";
import {TestERC20} from "../../src/mocks/TestERC20.sol";

import {isMainnet, isEthereum} from "../../src/utils/Constants.sol";

contract DeployTestERC20 is BaseDeployer {
    struct Deployment {
        address erc20;
    }

    Deployment deployment;

    /// @notice Deploys TestERC20 (only on L1 testnets)
    function run() external broadcaster {
        require(!isMainnet(), "TestERC20 should only be deployed on testnets");

        require(
            isEthereum(), "TestERC20 should only be deployed on L1 testnets"
        );

        deployment = deploy();

        writeToJson();

        generateTestnetData();
    }

    /// @notice Deploys TestERC20 on Anvil, Sepolia, Holesky
    /// @return Deployment address of TestERC20
    function deploy() public returns (Deployment memory) {
        TestERC20 erc20 = new TestERC20();
        print("TestERC20", address(erc20));

        return Deployment({erc20: address(erc20)});
    }

    /// @notice Mints and transfers tokens
    function generateTestnetData() private {
        TestERC20 erc20 = TestERC20(deployment.erc20);

        for (uint256 i = 0; i < 20; i++) {
            erc20.mint(deployer, 100_000 ether);
            if (i % 2 == 0) {
                erc20.transfer(getDeployedQueryClient(), 100_000 ether);
            }
        }
    }

    function writeToJson() private {
        vm.writeJson(
            vm.toString(address(deployment.erc20)),
            outputPath(),
            ".addresses.testERC20"
        );
    }
}
