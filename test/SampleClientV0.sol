// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LPNClientV0} from "../src/client/LPNClientV0.sol";
import {ILPNRegistry} from "../src/interfaces/ILPNRegistry.sol";
import {QueryParams} from "../src/utils/QueryParams.sol";

contract SampleClientV0 is LPNClientV0 {
    using QueryParams for QueryParams.NFTQueryParams;

    uint256 numHolders; // storage slot 1 (storage slot 0 is inherited)
    mapping(address holder => uint256 balance) balances; // storage slot 2

    mapping(uint256 requestId => address holder) requests;

    event Test(address holder, uint256[] results);

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
        uint88 offset = 0;
        uint256 requestId = lpnRegistry.request{value: lpnRegistry.gasFee()}(
            address(this),
            QueryParams.newNFTQueryParams(holder, offset).toBytes32(),
            block.number,
            block.number
        );

        // We can store the requestID if we need to access other data in the callback
        requests[requestId] = holder;
    }

    function lpnRegister() external {
        lpnRegistry.register(address(this), 2, 1);
    }

    function processCallback(uint256 requestId, uint256[] calldata results)
        internal
        override
    {
        // Process result
        address holder = requests[requestId];
        delete requests[requestId];
        emit Test(holder, results);
    }
}
