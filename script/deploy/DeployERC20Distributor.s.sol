// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {ERC20Distributor} from "../../src/v1/examples/ERC20Distributor.sol";
import {ILPNRegistryV1} from "../../src/v1/interfaces/ILPNRegistryV1.sol";

import {isMainnet} from "../../src/utils/Constants.sol";

contract DeployERC20Distributor is BaseScript {
    struct Deployment {
        address erc20;
    }

    Deployment deployment;

    /// @notice Deploys ERC20Distributor (only on testnets)
    function run() external broadcaster {
        require(
            !isMainnet(), "ERC20Distributor should only be deployed on testnets"
        );

        deployment = deploy();
    }

    /// @notice Deploys TestERC20 on Anvil, Sepolia, Holesky
    /// @return Deployment address of TestERC20
    function deploy() public returns (Deployment memory) {
        ERC20Distributor erc20 = new ERC20Distributor(
            ILPNRegistryV1(getDeployedRegistry(Version.V1))
        );
        print("ERC20Distributor", address(erc20));

        return Deployment({erc20: address(erc20)});
    }
}
