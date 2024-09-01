// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV0} from "../../src/v0/LPNRegistryV0.sol";
import {LPNQueryV0} from "../../src/v0/client/LPNQueryV0.sol";
import {PUDGEY_PENGUINS} from "../../src/utils/Constants.sol";

contract WithdrawFees is BaseScript {
    function run() external broadcaster {
        LPNRegistryV0(getDeployedRegistry()).withdrawFees();
    }
}
