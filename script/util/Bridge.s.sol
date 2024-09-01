// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV0} from "../../src/v0/LPNRegistryV0.sol";
import {LPNQueryV0} from "../../src/v0/client/LPNQueryV0.sol";
import {
    PUDGEY_PENGUINS,
    L1_BASE_BRIDGE,
    L1_FRAXTAL_BRIDGE,
    L1_FRAXTAL_HOLESKY_BRIDGE,
    L1_MANTLE_SEPOLIA_BRIDGE,
    L1_MANTLE_BRIDGE,
    isMainnet
} from "../../src/utils/Constants.sol";

contract Bridge is BaseScript {
    function run() external broadcaster {
        address bridgeAddr =
            isMainnet() ? L1_BASE_BRIDGE : L1_FRAXTAL_HOLESKY_BRIDGE;
        // isMainnet() ? L1_FRAXTAL_BRIDGE : L1_FRAXTAL_HOLESKY_BRIDGE;

        IL1StandardBridge opStackBridge = IL1StandardBridge(bridgeAddr);

        opStackBridge.bridgeETH{value: 0.01 ether}(200_000, new bytes(0));
    }
}

interface IL1StandardBridge {
    /**
     * @notice Sends ETH to the sender's address on the other chain.
     *
     * @param _minGasLimit Minimum amount of gas that the bridge can be relayed with.
     * @param _extraData   Extra data to be sent with the transaction. Note that the recipient will
     *                     not be triggered with this data, but it will be emitted and can be used
     *                     to identify the transaction.
     */
    function bridgeETH(uint32 _minGasLimit, bytes calldata _extraData)
        external
        payable;
}
