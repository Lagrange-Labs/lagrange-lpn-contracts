// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice Enum representing the types of operations supported by Lagrange.
enum OperationType {
    AVERAGE
}

struct Operation {
    OperationType op;
    bytes32 key;
}

/// @title ILPNRegistry
/// @notice Interface for the LPNRegistryV0 contract.
interface ILPNRegistry {
    /// @notice Event emitted when a new client registers.
    /// @param client The address of the registered client.
    /// @param mappingSlot The storage slot of the client's mapping to be computed and proved over.
    /// @param lengthSlot The storage slot of the variable storing the length of the client's mapping.
    event NewRegistration(
        address indexed client, uint256 mappingSlot, uint256 lengthSlot
    );

    /// @notice Event emitted when a new request is made.
    /// @param requestId The ID of the request.
    /// @param account The address of the smart contract with the storage associated with the request.
    /// @param key The key of the mapping for the value associated with the request.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @param op The operation to be calculated.
    event NewRequest(
        uint256 indexed requestId,
        address indexed account,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock,
        OperationType op
    );

    /// @notice Event emitted when a new request is made.
    /// @param requestId The ID of the request.
    /// @param client The address of the client who made the matching request.
    /// @param result The computed result for the request.
    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256 result
    );

    /// @notice Registers a client with the provided mapping and length slots.
    /// @param mappingSlot The storage slot of the client's mapping to be computed and proved over.
    /// @param lengthSlot The storage slot of the variable storing the length of the client's mapping.
    function register(uint256 mappingSlot, uint256 lengthSlot) external;

    /// @notice Submits a new request to the registry.
    /// @param account The address of the smart contract with the storage associated with the request.
    /// @param key The key of the mapping for the value associated with the request.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @param op The operation to be calculated.
    /// @return The ID of the newly created request.
    // TODO: Do we need the `key` ?
    function request(
        address account,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock,
        OperationType op
    ) external returns (uint256);

    /// @notice Submits a response to a specific request.
    /// @param requestId_ The ID of the request to respond to.
    /// @param result The result of the request.
    function respond(uint256 requestId_, uint256 result) external;
}
