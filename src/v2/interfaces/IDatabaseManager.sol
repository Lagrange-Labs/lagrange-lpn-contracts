// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IDatabaseManager
/// @notice Minimal interface for DatabaseManager functionality needed by QueryExecutor
interface IDatabaseManager {
    /// @notice Checks if a query is queryable
    /// @param hash The hash of the query
    /// @return isActive true if the query is queryable, false otherwise
    function isQueryActive(bytes32 hash) external view returns (bool);
}
