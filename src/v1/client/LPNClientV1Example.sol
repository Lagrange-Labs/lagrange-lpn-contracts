// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QueryOutput} from "../Groth16VerifierExtension.sol";

interface ILPNRegistryV1 {
    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256);
}

error CallbackNotAuthorized();

contract LPNClientV1Example {
    ILPNRegistryV1 public lpnRegistry;

    event NewResponse(uint256 requestId, QueryOutput result);

    modifier onlyLagrangeRegistry() {
        if (msg.sender != address(lpnRegistry)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    constructor(address _lpnRegistry) {
        lpnRegistry = ILPNRegistryV1(_lpnRegistry);
    }

    function lpnCallback(uint256 requestId, QueryOutput memory result)
        external
        onlyLagrangeRegistry
    {
        emit NewResponse(requestId, result);
    }

    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable {
        lpnRegistry.request{value: msg.value}(
            queryHash, placeholders, startBlock, endBlock
        );
    }
}
