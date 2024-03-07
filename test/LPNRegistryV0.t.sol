// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";

contract LPNRegistryV0Test is Test {
    LPNRegistryV0 public registry;

    function setUp() public {
        registry = new LPNRegistryV0();
    }
}
