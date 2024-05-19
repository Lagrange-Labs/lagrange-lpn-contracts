// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNQueryV0} from "../../src/client/LPNQueryV0.sol";
import {LPNRegistryV0} from "../../src/LPNRegistryV0.sol";
import {
    PUDGEY_PENGUINS,
    isEthereum,
    isMainnet
} from "../../src/utils/Constants.sol";
import {L1BlockNumber} from "../../src/utils/L1Block.sol";

contract Stake is BaseScript {
    address holeskyWeth = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;

    IMantleEth mantleEth =
        IMantleEth(0xbe16244EAe9837219147384c8A7560BA14946262);

    LPNRegistryV0 registry = LPNRegistryV0(getDeployedRegistry());
    LPNQueryV0 queryClient = LPNQueryV0(getDeployedQueryClient());

    function run() external broadcaster {
        stake();
    }

    function stake() private {
        // Deposit to get WETH
        // holeskyWeth.call{value: 1 ether}("");

        // Stake to get mETH
        mantleEth.stake{value: 100 ether}(0);
    }
}

interface IMantleEth {
    function stake(uint256 minMETHAmount) external payable;
}
