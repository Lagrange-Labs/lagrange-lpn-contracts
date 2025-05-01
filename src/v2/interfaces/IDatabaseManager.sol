// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IDatabaseManager
/// @notice Minimal interface for DatabaseManager functionality needed by QueryExecutor
interface IDatabaseManager {
    /// @notice Checks if a query is active
    /// @param hash The hash of the query
    /// @return isActive true if the query is active, false otherwise
    function isQueryActive(bytes32 hash) external view returns (bool);

    /// @notice Registers a new query
    /// @param hash The hash of the query, used as it's unique identifier
    /// @param tableID The hash of the table that the query is registered to
    /// @param sql The raw SQL of the query
    /// @dev The hash is deterministed from the SQL; if it doesn't match then the query is conidered invalid
    function registerQuery(bytes32 hash, bytes32 tableID, string calldata sql)
        external;
}
