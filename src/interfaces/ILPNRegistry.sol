// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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
    /// @param key The key of the mapping for the value associated with the request.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    event NewRequest(
        uint256 indexed requestId,
        address indexed storageContract,
        address indexed client,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock
    );

    /// @notice Event emitted when a response is received.
    /// @param requestId The ID of the request.
    /// @param client The address of the client who made the matching request.
    /// @param results The computed results for the request.
    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256[] results
    );

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
    /// @param key The key of the mapping for the value associated with the request.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @return The ID of the newly created request.
    function request(
        address storageContract,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock
    ) external returns (uint256);

    /// @notice Submits a response to a specific request.
    /// @param requestId_ The ID of the request to respond to.
    /// @param data The proof, inputs, and public inputs to verify.
    /// - groth16_proof.proofs: 8 * U256 = 256 bytes
    /// - groth16_proof.inputs: 3 * U256 = 96 bytes
    /// - plonky2_proof.public_inputs: the little-endian bytes of public inputs exported by user
    function respond(uint256 requestId_, bytes32[] calldata data) external;
}
