// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IQueryManager
/// @notice
interface IQueryManager {
    /// @notice Event emitted when a new request is made.
    /// @param requestId The ID of the request.
    /// @param queryHash The identifier of the SQL query associated with the request.
    /// @param client The address of the client who made this request.
    /// @param params The query params associated with this query type.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @param proofBlock The requested block for the proof to be computed against.
    ///                   Currently required for OP Stack chains
    event NewRequest(
        uint256 indexed requestId,
        bytes32 indexed queryHash,
        address indexed client,
        bytes params,
        uint256 startBlock,
        uint256 endBlock,
        uint256 gasFee,
        uint256 proofBlock
    );

    /// @notice Event emitted when a response is received.
    /// @param requestId The ID of the request.
    /// @param client The address of the client who made the matching request.
    /// @param results The computed results for the request.
    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256[] results
    );

    /// @notice Submits a new request to the registry.
    /// @param queryHash The identifier of the SQL query associated with the request.
    /// @param params The dynamic query params associated with the query.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @return The ID of the newly created request.
    function request(
        bytes32 queryHash,
        bytes calldata params,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256);

    /// @notice Submits a response to a specific request.
    /// @param requestId_ The ID of the request to respond to.
    /// @param data The proof, inputs, and public inputs to verify.
    /// - groth16_proof.proofs: 8 * U256 = 256 bytes
    /// - groth16_proof.inputs: 3 * U256 = 96 bytes
    /// - plonky2_proof.public_inputs: the little-endian bytes of public inputs exported by user
    /// @param blockNumber The block number of the block hash corresponding to the proof.
    function respond(
        uint256 requestId_,
        bytes32[] calldata data,
        uint256 blockNumber
    ) external;
}
