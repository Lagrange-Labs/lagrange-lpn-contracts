// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNQueryV0} from "../../src/client/LPNQueryV0.sol";
import {LPNRegistryV0} from "../../src/LPNRegistryV0.sol";
import {PUDGEY_PENGUINS} from "../../src/utils/Constants.sol";
import {isOPStack} from "../../src/utils/Constants.sol";
import {L1BlockNumber} from "../../src/utils/L1Block.sol";
import {console} from "forge-std/console.sol";

contract Query is BaseScript {
    LPNRegistryV0 registry = LPNRegistryV0(getDeployedRegistry());
    LPNQueryV0 queryClient = LPNQueryV0(getDeployedRegistry());

    function run() external broadcaster {
        address holder = deployer;
        query(holder);
    }

    function query(address holder) private {
        uint256 endBlock = L1BlockNumber();
        uint256 startBlock = endBlock - 10;
        uint8 offset = 0;

        queryClient.query{value: registry.gasFee()}(
            getDeployedStorageContract(), holder, startBlock, endBlock, offset
        );
    }
}
