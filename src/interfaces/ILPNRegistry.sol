// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Groth16VerifierExtensions} from "../Groth16VerifierExtensions.sol";

uint8 constant LEGACY_QUERY_IDENTIFIER = 0;
uint8 constant NFT_QUERY_IDENTIFIER =
    uint8(Groth16VerifierExtensions.QUERY_IDENTIFIER_NFT);
uint8 constant ERC20_QUERY_IDENTIFIER =
    uint8(Groth16VerifierExtensions.QUERY_IDENTIFIER_ERC20);

/// @title ILPNRegistry
/// @notice Interface for the LPNRegistryV0 contract.
interface ILPNRegistry {
    /// @notice Event emitted when a new client registers.
    /// @param storageContract The address of the smart contract to be indexed.
    /// @param client The address of the client who requested this contract to be indexed.
    /// @param mappingSlot The storage slot of the client's mapping to be computed and proved over.
    /// @param lengthSlot The storage slot of the variable storing the length of the client's mapping.
    event NewRegistration(
        address indexed storageContract,
        address indexed client,
        uint256 mappingSlot,
        uint256 lengthSlot
    );

    /// @notice Event emitted when a new request is made.
    /// @param requestId The ID of the request.
    /// @param storageContract The address of the smart contract with the storage associated with the request.
    /// @param client The address of the client who made this request.
    /// @param params The query params associated with this query type.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @param proofBlock The requested block for the proof to be computed against.
    ///                   Currently required for OP Stack chains
    event NewRequest(
        uint256 indexed requestId,
        address indexed storageContract,
        address indexed client,
        bytes32 params,
        uint256 startBlock,
        uint256 endBlock,
        uint256 offset,
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

    /// @notice Calldata parameters for an NFT Query
    /// @param identifier The identifier for the query type
    /// @param userAddress The address of the user associated with the query
    /// @param offset The offset value for pagination or data fetching
    struct NFTQueryParams {
        uint8 identifier;
        address userAddress;
        uint88 offset;
    }

    /// @notice Calldata parameters for an ERC20 Query
    /// @param identifier The identifier for the query type
    /// @param userAddress The address of the user associated with the query
    /// @param rewardsRate The rewards rate for the ERC20 token
    struct ERC20QueryParams {
        uint8 identifier;
        address userAddress;
        uint88 rewardsRate;
    }

    /// @notice Combined structure of all possible query parameters
    /// @param identifier The identifier for the query type
    /// @param userAddress The address of the user associated with the query
    /// @param rewardsRate The rewards rate for the ERC20 token
    /// @param offset The offset value for pagination or data fetching
    struct CombinedParams {
        uint8 identifier;
        address userAddress;
        uint88 rewardsRate;
        uint88 offset;
    }

    /// @notice The gas fee paid for on request to reimburse the response transaction.
    function gasFee() external returns (uint256);

    /// @notice Registers a client with the provided mapping and length slots.
    /// @param storageContract The address of the contract to be queried.
    /// @param mappingSlot The storage slot of the client's mapping to be computed and proved over.
    /// @param lengthSlot The storage slot of the variable storing the length of the client's mapping.
    function register(
        address storageContract,
        uint256 mappingSlot,
        uint256 lengthSlot
    ) external;

    /// @notice Submits a new request to the registry.
    /// @param storageContract The address of the smart contract with the storage associated with the request.
    /// @param params The query params associated with this query type.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.

    /// @custom:deprecated `offset` is only supported and necessary for legacy queries; for new NFT queries, specify as `params.offset`
    /// @param offset The ending block for the computation.

    /// @return The ID of the newly created request.
    function request(
        address storageContract,
        bytes32 params,
        uint256 startBlock,
        uint256 endBlock,
        uint256 offset
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
