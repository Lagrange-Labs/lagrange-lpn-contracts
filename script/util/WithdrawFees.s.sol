// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV1} from "../../src/v1/LPNRegistryV1.sol";

contract WithdrawFees is BaseScript {
    function run() external isBatch(address(SAFE)) {
        bytes memory txn =
            abi.encodeWithSelector(LPNRegistryV1.withdrawFees.selector);

        addToBatch(getDeployedRegistry(Version.V1), txn);

        executeBatch(true);
    }
}
