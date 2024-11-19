// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {isEthereum, isOPStack, isMantle, isCDK} from "../utils/Constants.sol";
import {IRegistrationManager} from "./interfaces/IRegistrationManager.sol";

/// @title RegistrationManager
/// @notice TODO
contract RegistrationManager is IRegistrationManager {
    /// @notice Mapping to track registered tables
    mapping(bytes32 hash => bool registered) public tables;

    /// @notice Mapping to track registered queries
    mapping(bytes32 hash => bool registered) public queries;

    /// @dev Reserves storage slots for future upgrades
    uint256[48] private __gap;

    /// @notice Error thrown when attempting to register a table more than once.
    error TableAlreadyRegistered();

    /// @notice Error thrown when attempting to register a query more than once.
    error QueryAlreadyRegistered();

    function _registerTable(
        bytes32 hash,
        address contractAddr,
        uint96 chainId,
        uint256 genesisBlock,
        string calldata name, // TODO: Should we save name?
        string calldata schema
    ) internal {
        if (tables[hash]) {
            revert TableAlreadyRegistered();
        }

        tables[hash] = true; // TODO: Do we need this?

        emit NewTableRegistration(
            hash, contractAddr, chainId, genesisBlock, name, schema
        );
    }

    function registerQuery(bytes32 hash, bytes32 tableHash, string calldata sql)
        external
    {
        if (queries[hash]) {
            revert QueryAlreadyRegistered();
        }

        queries[hash] = true; // TODO: Do we need this?

        emit NewQueryRegistration(hash, tableHash, sql);
    }
}
