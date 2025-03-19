// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/AccessControlUpgradeable.sol";
import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";
import {IDatabaseManager} from "./interfaces/IDatabaseManager.sol";

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
    /// @notice The semantic version of the contract
    string public constant VERSION = "1.0.0";

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @notice Mapping to track registered tables
    mapping(bytes32 tableID => bool registered) private s_tables;

    /// @notice Mapping to track registered queries, and the tables they are registered to
    mapping(bytes32 queryHash => bytes32 tableID) private s_queries;

    /// @notice Emitted when a new table is registered
    event NewTableRegistered(bytes32 indexed id);

    /// @notice Emitted when a table is deleted
    event TableDeleted(bytes32 indexed id);

    /// @notice Emitted when a new query is registered.
    event NewQueryRegistered(
        bytes32 indexed hash, bytes32 indexed tableID, string sql
    );

    /// @notice Error thrown when attempting to register a table more than once
    error TableAlreadyRegistered();

    /// @notice Error thrown when attempting to register a query more than once
    error QueryAlreadyRegistered();

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
        if (s_tables[id]) {
            revert TableAlreadyRegistered();
        }
        s_tables[id] = true;
        emit NewTableRegistered(id);
    }

    /// @notice Deletes a registered table
    /// @param id The id of the table to delete
    function deleteTable(bytes32 id) external onlyRole(OWNER_ROLE) {
        delete s_tables[id];
        emit TableDeleted(id);
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
        emit NewQueryRegistered(hash, tableID, sql);
    }

    /// @inheritdoc IDatabaseManager
    function isQueryActive(bytes32 hash) public view returns (bool) {
        return s_tables[s_queries[hash]];
    }

    /// @notice Checks if a table is registered
    /// @param id The id of the table
    /// @return bool Trueif the table is registered, false otherwise
    function isTableActive(bytes32 id) external view returns (bool) {
        return s_tables[id];
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
}
