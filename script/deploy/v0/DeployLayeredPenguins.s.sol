// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../../BaseScript.s.sol";
import {LPNRegistryV0} from "../../../src/v0/LPNRegistryV0.sol";
import {LayeredPenguins} from "../../../src/v0/examples/LayeredPenguins.sol";

contract DeployLayeredPenguins is BaseScript {
    struct Deployment {
        LayeredPenguins lp;
    }

    LPNRegistryV0 registry;
    Deployment deployment;

    function run() external broadcaster {
        registry = LPNRegistryV0(getDeployedRegistry(Version.V0));
        deployment = deploy();
    }

    function deploy() public returns (Deployment memory) {
        LayeredPenguins lp = new LayeredPenguins(registry);

        print("LayeredPenguins", address(lp));

        return Deployment({lp: lp});
    }
}
