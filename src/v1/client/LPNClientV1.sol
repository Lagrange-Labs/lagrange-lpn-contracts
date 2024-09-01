// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILPNClientV1} from "../interfaces/ILPNClientV1.sol";
import {ILPNRegistryV1} from "../interfaces/ILPNRegistryV1.sol";
import {QueryOutput} from "../Groth16VerifierExtensions.sol";

error CallbackNotAuthorized();

abstract contract LPNClientV1 is ILPNClientV1 {
    ILPNRegistryV1 public lpnRegistry;

    modifier onlyLagrangeRegistry() {
        if (msg.sender != address(lpnRegistry)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    constructor(ILPNRegistryV1 _lpnRegistry) {
        lpnRegistry = _lpnRegistry;
    }

    function lpnCallback(uint256 requestId, QueryOutput memory result)
        external
        onlyLagrangeRegistry
    {
        processCallback(requestId, result);
    }

    function processCallback(uint256 requestId, QueryOutput memory result)
        internal
        virtual;
}
