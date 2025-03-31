// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QueryOutput} from "../Groth16VerifierExtension.sol";
import {ILagrangeQueryRouter} from "../interfaces/ILagrangeQueryRouter.sol";
import {ILPNClient} from "../interfaces/ILPNClient.sol";

error CallbackNotAuthorized();

contract LPNClientV2Example is ILPNClient {
    ILagrangeQueryRouter public lpnRouter;

    event NewResponse(uint256 requestId, QueryOutput result);

    modifier onlyLagrangeRouter() {
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
        onlyLagrangeRouter
    {
        emit NewResponse(requestId, result);
    }

    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256) {
        return lpnRouter.request{value: msg.value}(
            queryHash, callbackGasLimit, placeholders, startBlock, endBlock
        );
    }

    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) external payable returns (uint256) {
        return lpnRouter.request{value: msg.value}(
            queryHash,
            callbackGasLimit,
            placeholders,
            startBlock,
            endBlock,
            limit,
            offset
        );
    }
}
