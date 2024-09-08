// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IRegistrationManager
/// @notice
interface IRegistrationManager {
    event NewTableRegistration(
        bytes32 indexed hash,
        address indexed contractAddr,
        uint256 chainId,
        uint256 genesisBlock,
        string name,
        string schema
    );

    event NewQueryRegistration(
        bytes32 indexed hash, bytes32 indexed tableHash, string sql
    );

    function registerQuery(bytes32 hash, bytes32 tableHash, string calldata sql)
        external;
}
