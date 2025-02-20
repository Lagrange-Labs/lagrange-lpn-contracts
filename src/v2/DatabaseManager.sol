// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVersioned} from "../interfaces/IVersioned.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/AccessControlUpgradeable.sol";
import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";

/// @title DatabaseManager
/// @notice Manages the registration of tables and queries for the system
/// @dev This contract is upgradable
/// @dev AccessControl is used instead of Ownable for better upgradability in case future roles are required
contract DatabaseManager is
    Initializable,
    AccessControlUpgradeable,
    IVersioned
{
    /// @notice The semantic version of the contract
    string public constant version = "1.0.0";

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @notice Mapping to track registered tables
    mapping(bytes32 tableHash => bool registered) private s_tables;

    /// @notice Mapping to track registered queries, and the tables they are registered to
    mapping(bytes32 queryHash => bytes32 tableHash) private s_queries;

    /// @notice Emitted when a new table is registered
    event NewTableRegistration(
        bytes32 indexed hash,
        address indexed contractAddr,
        uint256 chainId,
        uint256 genesisBlock,
        string name,
        string schema
    );

    /// @notice Emitted when a table is deleted
    event TableDeleted(bytes32 indexed hash);

    /// @notice Emitted when a new query is registered.
    event NewQueryRegistration(
        bytes32 indexed hash, bytes32 indexed tableHash, string sql
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
    function initialize(address initialOwner) public initializer {
        __AccessControl_init();
        _grantRole(OWNER_ROLE, initialOwner);
    }

    /// @notice Registers a new table
    /// @param hash The hash of the table, used as it's unique identifier
    /// @param contractAddr The address of the contract that is registering the table
    /// @param chainId The chain ID of the table
    /// @param genesisBlock The genesis block of the table
    /// @param name The name of the table
    /// @param schema The schema of the table
    function registerTable(
        bytes32 hash,
        address contractAddr,
        uint96 chainId,
        uint256 genesisBlock,
        string calldata name,
        string calldata schema
    ) external onlyRole(OWNER_ROLE) {
        if (s_tables[hash]) {
            revert TableAlreadyRegistered();
        }
        s_tables[hash] = true;
        emit NewTableRegistration(
            hash, contractAddr, chainId, genesisBlock, name, schema
        );
    }

    /// @notice Deletes a registered table
    /// @param hash The hash of the table to delete
    function deleteTable(bytes32 hash) external onlyRole(OWNER_ROLE) {
        delete s_tables[hash];
        emit TableDeleted(hash);
    }

    /// @notice Registers a new query
    /// @param hash The hash of the query, used as it's unique identifier
    /// @param tableHash The hash of the table that the query is registered to
    /// @param sql The raw SQL of the query
    /// @dev The hash is deterministed from the SQL; if it doesn't match then the query is conidered invalid
    // TODO: We should consider charging a small fee for registering a new query to prevent spam
    function registerQuery(bytes32 hash, bytes32 tableHash, string calldata sql)
        external
    {
        if (s_queries[hash] != bytes32(0)) {
            revert QueryAlreadyRegistered();
        }
        s_queries[hash] = tableHash;
        emit NewQueryRegistration(hash, tableHash, sql);
    }

    /// @notice Checks if a query is queryable
    /// @param hash The hash of the query
    /// @return True if the query is queryable, false otherwise
    function isQueryActive(bytes32 hash) public view returns (bool) {
        return s_tables[s_queries[hash]];
    }

    /// @notice Checks if a table is registered
    /// @param hash The hash of the table
    /// @return bool Trueif the table is registered, false otherwise
    function isTableActive(bytes32 hash) external view returns (bool) {
        return s_tables[hash];
    }

    /// @notice Gets the table hash associated with a query
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
