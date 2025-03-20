// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QueryOutput} from "../Groth16VerifierExtension.sol";

interface ILagrangeQueryRouter {
    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256);
}

error CallbackNotAuthorized();

contract LPNClientV2Example {
    ILagrangeQueryRouter public lpnRouter;

    event NewResponse(uint256 requestId, QueryOutput result);

    modifier onlyLagrangeRegistry() {
        if (msg.sender != address(lpnRouter)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    constructor(address router) {
        lpnRouter = ILagrangeQueryRouter(router);
    }

    function lpnCallback(uint256 requestId, QueryOutput memory result)
        external
        onlyLagrangeRegistry
    {
        emit NewResponse(requestId, result);
    }

    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable {
        lpnRouter.request{value: msg.value}(
            queryHash, callbackGasLimit, placeholders, startBlock, endBlock
        );
    }
}
