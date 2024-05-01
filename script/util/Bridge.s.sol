// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNRegistryV0} from "../../src/LPNRegistryV0.sol";
import {LPNQueryV0} from "../../src/client/LPNQueryV0.sol";
import {PUDGEY_PENGUINS, L1_BASE_BRIDGE} from "../../src/utils/Constants.sol";

contract Bridge is BaseScript {
    function run() external broadcaster {
        IBaseBridge baseBridge = IBaseBridge(L1_BASE_BRIDGE);
        baseBridge.bridgeETH{value: 0.01 ether}(200_000, new bytes(0));
    }
}

interface IBaseBridge {
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
