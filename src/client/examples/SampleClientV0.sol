// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LPNClientV0} from "../LPNClientV0.sol";
import {ILPNRegistry, OperationType} from "../../interfaces/ILPNRegistry.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SampleClientV0 is LPNClientV0 {
    uint256 numHolders; // storage slot 1 (storage slot 0 is inherited)
    mapping(address holder => uint256 balance) balances; // storage slot 2

    mapping(uint256 requestId => address holder) requests;

    constructor(ILPNRegistry lpnRegistry) LPNClientV0(lpnRegistry) {}

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
            address(this),
            bytes32(uint256(uint160(holder))),
            block.number - 10,
            block.number,
            OperationType.AVERAGE
        );

        // We can store the requestID if we need to access other data in the callback
        requests[requestId] = holder;
    }

    function lpnRegister() external {
        lpnRegistry.register(address(this), 2, 1);
    }

    function processCallback(uint256 requestId, uint256 result)
        internal
        override
    {
        address holder = requests[requestId];
        // Process result
    }
}
