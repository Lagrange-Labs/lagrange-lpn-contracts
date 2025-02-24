// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryOutput, QueryInput} from "../Groth16VerifierExtension.sol";

/// @title IQueryExecutor
/// @notice Interface for the QueryExecutor contract that handles requesting and responding to queries
interface IQueryExecutor {
    /// @notice Makes a request with specified limit and offset values
    /// @param client The address that will receive the response
    /// @param queryHash The hash of the query to execute
    /// @param callbackGasLimit The maximum amount of gas to use for the callback
    /// @param placeholders The placeholder values for the query
    /// @param startBlock The starting block number for the query range
    /// @param endBlock The ending block number for the query range
    /// @param limit The maximum number of rows to return
    /// @param offset The number of rows to skip
    /// @return The ID of the created request
    function request(
        address client,
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) external payable returns (uint256);

    /// @notice Responds to a query request
    /// @param requestId The ID of the request to respond to
    /// @param data The response data
    /// @return client The address of the client that made the request
    /// @return callbackGasLimit The gas limit for the callback
    /// @return result The processed query output
    function respond(uint256 requestId, bytes32[] calldata data)
        external
        returns (
            address client,
            uint256 callbackGasLimit,
            QueryOutput memory result
        );

    /// @notice Returns the fee for a query
    /// @param queryHash The hash of the query
    /// @param callbackGasLimit The gas limit for the callback
    /// @param blockRange The number of blocks to query
    /// @return fee The fee for the query
    function getFee(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        uint256 blockRange
    ) external view returns (uint256);
}
