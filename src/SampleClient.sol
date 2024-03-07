// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LPNClientV0} from "./LPNClientV0.sol";
import {LPNRegistryV0, OperationType} from "./LPNRegistryV0.sol";

contract SampleClientV0 is LPNClientV0 {
    uint256 numHolders; // storage slot 0
    mapping(address holder => uint256 balance) balances; // storage slot 1

    mapping(uint256 requestId => address holder) requests;

    LPNRegistryV0 public lpnRegistry;

    function addHolder(address holder, uint256 amount) external {
        balances[holder] = amount;
        // Ensure your counter variable tracks your mapping size
        numHolders++;
    }

    function removeHolder(address holder) external {
        balances[holder] = 0;
        // Ensure your counter variable tracks your mapping size
        numHolders--;
    }

    function queryAverage(address holder) external {
        uint256 requestId = lpnRegistry.request(
            address(this), bytes32(uint256(uint160(holder))), block.number - 10, block.number, OperationType.AVERAGE
        );

        // We can store the requestID if we need to access other data in the callback
        requests[requestId] = holder;
    }

    function lpnRegister() external {
        lpnRegistry.register(1, 0);
    }

    function lpnCallback(uint256 requestId, uint256 result) external override {
        address holder = requests[requestId];
        // Process result
    }
}
