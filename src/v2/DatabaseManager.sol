// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/AccessControlUpgradeable.sol";
import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";
import {IDatabaseManager} from "./interfaces/IDatabaseManager.sol";
import {EnumerableSet} from
    "@openzeppelin-contracts-5.2.0/utils/structs/EnumerableSet.sol";

/// @title DatabaseManager
/// @notice Manages the registration of tables and queries for the system
/// @dev This contract is upgradable
/// @dev AccessControl is used instead of Ownable for better upgradability in case future roles are required
contract DatabaseManager is
    Initializable,
    AccessControlUpgradeable,
    IDatabaseManager,
    IVersioned
{
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice The semantic version of the contract
    string public constant VERSION = "1.0.0";

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @notice Set to track registered table IDs
    EnumerableSet.Bytes32Set private s_tableIDs;

    /// @notice Set to track registered query hashes for each table
    mapping(bytes32 tableID => EnumerableSet.Bytes32Set queries) private
        s_queriesByTable;

    /// @notice Mapping to track registered queries, and the tables they are registered to
    mapping(bytes32 queryHash => bytes32 tableID) private s_queries;

    /// @notice Emitted when a new table is registered
    event NewTableRegistered(bytes32 indexed id);

    /// @notice Emitted when a table is deleted
    event TableDeleted(bytes32 indexed id);

    /// @notice Emitted when a query is deleted
    event QueryDeleted(bytes32 indexed hash);

    /// @notice Emitted when a new query is registered.
    event NewQueryRegistered(
        bytes32 indexed hash, bytes32 indexed tableID, string sql
    );

    /// @notice Error thrown when attempting to register a table more than once
    error TableAlreadyRegistered();

    /// @notice Error thrown when attempting to delete a table that does not exist
    error TableDoesNotExist();

    /// @notice Error thrown when attempting to register a query more than once
    error QueryAlreadyRegistered();

    /// @notice Error thrown when attempting to delete a query that does not exist
    error QueryDoesNotExist();

    /// @notice Error thrown when attempting to access an invalid index range
    error InvalidIndexRange();

    /// @notice We disable initializers to prevent the initializer from being called directly on the implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param initialOwner The owner of the contract
    function initialize(address initialOwner) public initializer {
        __AccessControl_init();
        _grantRole(OWNER_ROLE, initialOwner);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
    }

    /// @notice Registers a new table
    /// @param id The unique identifier for the table, generated off-chain
    function registerTable(bytes32 id) external onlyRole(OWNER_ROLE) {
        if (!s_tableIDs.add(id)) revert TableAlreadyRegistered();
        emit NewTableRegistered(id);
    }

    /// @notice Deletes a registered table
    /// @param id The id of the table to delete
    function deleteTable(bytes32 id) external onlyRole(OWNER_ROLE) {
        if (!s_tableIDs.remove(id)) revert TableDoesNotExist();
        emit TableDeleted(id);
    }

    /// @notice Deletes a registered query
    /// @param queryHash The id of the query to delete
    function deleteQuery(bytes32 queryHash) external onlyRole(OWNER_ROLE) {
        if (s_queries[queryHash] == bytes32(0)) revert QueryDoesNotExist();
        bytes32 tableID = s_queries[queryHash];
        s_queriesByTable[tableID].remove(queryHash);
        delete s_queries[queryHash];
        emit QueryDeleted(queryHash);
    }

    /// @notice Registers a new query
    /// @param hash The hash of the query, used as it's unique identifier
    /// @param tableID The hash of the table that the query is registered to
    /// @param sql The raw SQL of the query
    /// @dev The hash is deterministed from the SQL; if it doesn't match then the query is conidered invalid
    function registerQuery(bytes32 hash, bytes32 tableID, string calldata sql)
        external
    {
        if (s_queries[hash] != bytes32(0)) {
            revert QueryAlreadyRegistered();
        }
        s_queries[hash] = tableID;
        s_queriesByTable[tableID].add(hash);
        emit NewQueryRegistered(hash, tableID, sql);
    }

    /// @inheritdoc IDatabaseManager
    function isQueryActive(bytes32 hash) public view returns (bool) {
        return s_tableIDs.contains(s_queries[hash]);
    }

    /// @notice Checks if a table is registered
    /// @param id The id of the table
    /// @return bool True if the table is registered, false otherwise
    function isTableActive(bytes32 id) external view returns (bool) {
        return s_tableIDs.contains(id);
    }

    /// @notice Gets the tableID associated with a query
    /// @param queryHash The hash of the query
    /// @return bytes32 The id of the table the query is registered to
    function getTableForQuery(bytes32 queryHash)
        external
        view
        returns (bytes32)
    {
        return s_queries[queryHash];
    }

    /// @notice Gets a range of registered table IDs
    /// @param start The starting index (inclusive)
    /// @param end The ending index (exclusive)
    /// @return bytes32[] Array of table IDs in the specified range
    function getTables(uint256 start, uint256 end)
        external
        view
        returns (bytes32[] memory)
    {
        if (start >= end || end > s_tableIDs.length()) {
            revert InvalidIndexRange();
        }
        bytes32[] memory result = new bytes32[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = s_tableIDs.at(i);
        }
        return result;
    }

    /// @notice Gets a range of registered query hashes for a specific table
    /// @param tableID The ID of the table to get queries for
    /// @param start The starting index (inclusive)
    /// @param end The ending index (exclusive)
    /// @return bytes32[] Array of query hashes in the specified range
    function getQueries(bytes32 tableID, uint256 start, uint256 end)
        external
        view
        returns (bytes32[] memory)
    {
        if (start >= end || end > s_queriesByTable[tableID].length()) {
            revert InvalidIndexRange();
        }
        bytes32[] memory result = new bytes32[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = s_queriesByTable[tableID].at(i);
        }
        return result;
    }

    /// @notice Gets the total number of registered tables
    /// @return numTables The number of registered tables
    function getNumTables() external view returns (uint256) {
        return s_tableIDs.length();
    }

    /// @notice Gets the total number of registered queries for a specific table
    /// @param tableID The ID of the table to get the number of queries for
    /// @return numQueries The number of registered queries
    function getNumQueries(bytes32 tableID) external view returns (uint256) {
        return s_queriesByTable[tableID].length();
    }
}
