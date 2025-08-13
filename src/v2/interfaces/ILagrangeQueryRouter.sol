// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILagrangeQueryRouter {
    /// @notice Makes an aggregation query request to the default QueryExecutor
    /// @param queryHash The hash of the query to execute
    /// @param callbackGasLimit The gas limit for the callback
    /// @param placeholders The placeholder values for the query
    /// @param startBlock The starting block number for the query range
    /// @param endBlock The ending block number for the query range
    /// @return requestId The ID of the request
    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256);

    /// @notice Makes a query request to the default QueryExecutor
    /// @param queryHash The hash of the query to execute
    /// @param callbackGasLimit The gas limit for the callback
    /// @param placeholders The placeholder values for the query
    /// @param startBlock The starting block number for the query range
    /// @param endBlock The ending block number for the query range
    /// @param limit The maximum number of rows to return
    /// @param offset The number of rows to skip
    /// @return requestId The ID of the request

    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) external payable returns (uint256);
}
