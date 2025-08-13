// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QueryOutput} from "../Groth16VerifierExtension.sol";
import {ILagrangeQueryRouter} from "../interfaces/ILagrangeQueryRouter.sol";
import {ILPNClient} from "../interfaces/ILPNClient.sol";

error CallbackNotAuthorized();

/// @title LPN Client V2 Example
/// @notice Minimal example implementation of `ILPNClient` that forwards requests to a
/// Lagrange Query Router and receives verified results via a callback.
contract LPNClientV2Example is ILPNClient {
    ILagrangeQueryRouter public lpnRouter;

    event NewResponse(uint256 requestId, QueryOutput result);

    /// @notice Modifier to ensure only the Lagrange Query Router can call the callback.
    modifier onlyLagrangeRouter() {
        if (msg.sender != address(lpnRouter)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    /// @notice Initializes the client with the Lagrange Query Router.
    /// @param router The address of the `ILagrangeQueryRouter` that will process
    /// requests and invoke callbacks.
    constructor(address router) {
        lpnRouter = ILagrangeQueryRouter(router);
    }

    /// @notice Callback invoked by the Lagrange Query Router with the query result.
    /// @dev Only callable by the configured router.
    /// @param requestId The unique identifier of the original request.
    /// @param result The verified query output produced by LPN.
    function lpnCallback(uint256 requestId, QueryOutput calldata result)
        external
        onlyLagrangeRouter
    {
        emit NewResponse(requestId, result);
    }

    /// @notice Submits a query to the Lagrange Query Router.
    /// @param queryHash The unique hash identifying the query template.
    /// @param callbackGasLimit The gas limit to forward to the `lpnCallback` execution.
    /// @param placeholders Values to substitute for placeholder variables in the query.
    /// @param startBlock The inclusive starting block for the query's block range.
    /// @param endBlock The inclusive ending block for the query's block range.
    /// @return requestId The identifier assigned to the created request.
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

    /// @notice Submits a paginated query to the Lagrange Query Router.
    /// @param queryHash The unique hash identifying the query template.
    /// @param callbackGasLimit The gas limit to forward to the `lpnCallback` execution.
    /// @param placeholders Values to substitute for placeholder variables in the query.
    /// @param startBlock The inclusive starting block for the query's block range.
    /// @param endBlock The inclusive ending block for the query's block range.
    /// @param limit The maximum number of results to return.
    /// @param offset The number of results to skip from the beginning.
    /// @return requestId The identifier assigned to the created request.
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
