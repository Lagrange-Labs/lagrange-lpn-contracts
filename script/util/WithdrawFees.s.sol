// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV0} from "../../src/LPNRegistryV0.sol";
import {LPNQueryV0} from "../../src/client/LPNQueryV0.sol";
import {PUDGEY_PENGUINS} from "../../src/utils/Constants.sol";

contract WithdrawFees is BaseScript {
    function run() external broadcaster {
        LPNRegistryV0(0x2584665Beff871534118aAbAE781BC267Af142f9).withdrawFees();
    }
}
