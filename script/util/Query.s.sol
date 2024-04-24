// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNQueryV0} from "../../src/client/LPNQueryV0.sol";
import {PUDGEY_PENGUINS} from "../../src/utils/Constants.sol";

contract Query is BaseScript {
    function run() external broadcaster {
        query(
            LPNQueryV0(0x80c0a42F808d6f35e83F4939482A485caE536e6a),
            0x29469395eAf6f95920E59F858042f0e28D98a20B
        );
    }

    function query(LPNQueryV0 queryClient, address holder) private {
        uint256 startBlock = 19680500;
        uint256 endBlock = startBlock + 1000;
        uint8 offset = 0;
        queryClient.query{value: 0.05 ether}(
            PUDGEY_PENGUINS, holder, startBlock, endBlock, offset
        );
    }
}
