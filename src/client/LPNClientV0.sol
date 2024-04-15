// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILPNRegistry} from "../interfaces/ILPNRegistry.sol";
import {ILPNClient} from "../interfaces/ILPNClient.sol";

error CallbackNotAuthorized();

abstract contract LPNClientV0 is ILPNClient {
    ILPNRegistry public lpnRegistry;

    modifier onlyLagrangeRegistry() {
        if (msg.sender != address(lpnRegistry)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    constructor(ILPNRegistry _lpnRegistry) {
        lpnRegistry = _lpnRegistry;
    }

    function lpnCallback(uint256 requestId, uint256[] calldata results)
        external
        onlyLagrangeRegistry
    {
        processCallback(requestId, results);
    }

    function processCallback(uint256 requestId, uint256[] calldata results)
        internal
        virtual;
}
