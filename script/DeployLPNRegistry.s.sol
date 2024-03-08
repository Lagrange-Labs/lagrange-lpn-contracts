// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseScript} from "./BaseScript.s.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";

contract DeployLPNRegistry is BaseScript {
    LPNRegistryV0 registry;

    function run() external returns (LPNRegistryV0) {
        registry = deploy(salt);
        assertions();
        print("LPNRegistryV0", address(registry));
        return registry;
    }

    function deploy(bytes32 _salt) public broadcaster returns (LPNRegistryV0) {
        return new LPNRegistryV0{salt: _salt}();
    }

    function assertions() private view {}
}
