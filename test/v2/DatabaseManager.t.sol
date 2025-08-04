// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {BaseTest} from "../BaseTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DatabaseManagerTest is BaseTest {
    DatabaseManager public implementation;
    DatabaseManager public dbManager;
    address public owner;
    address public stranger;

    // Test data
    string public constant TEST_SQL = "SELECT * FROM test_table";
    bytes32 public constant QUERY_HASH = keccak256("test_query");
    bytes32 public constant TABLE_ID = keccak256("test_table");
    bytes32 public constant TABLE_ID_2 = keccak256("test_table_2");
    string public constant TEST_SQL_2 = "SELECT * FROM test_table_2";
    bytes32 public constant QUERY_HASH_2 = keccak256("test_query_2");
    bytes32 public constant QUERY_HASH_3 = keccak256("test_query_3");
    bytes32 public constant QUERY_HASH_4 = keccak256("test_query_4");

    function setUp() public virtual {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");

        implementation = new DatabaseManager();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            abi.encodeWithSelector(DatabaseManager.initialize.selector, owner)
        );

        // cast the proxy to as the DatabaseManager contract, the base test suite will do the rest!
        dbManager = DatabaseManager(address(proxy));
    }

    function test_Constructor() public view {
        assertEq(dbManager.VERSION(), "1.0.0");
    }

    function test_Initialize() public view {
        assertTrue(dbManager.hasRole(keccak256("OWNER_ROLE"), owner));
        assertFalse(dbManager.hasRole(keccak256("OWNER_ROLE"), stranger));
        assertEq(
            dbManager.getRoleAdmin(keccak256("OWNER_ROLE")),
            keccak256("OWNER_ROLE")
        );
    }

    function test_Initialize_RevertsIf_DuplicateAttempt() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        dbManager.initialize(stranger);
    }

    function test_Initialize_RevertsIf_CalledDirectlyOnImplementation()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        implementation.initialize(stranger);
    }

    function test_RegisterTable_Success() public {
        vm.prank(owner);

        vm.expectEmit();
        emit DatabaseManager.NewTableRegistered(TABLE_ID);
        dbManager.registerTable(TABLE_ID);

        assertTrue(dbManager.isTableActive(TABLE_ID));
    }

    function test_RegisterTable_RevertIfNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                stranger,
                keccak256("OWNER_ROLE")
            )
        );
        dbManager.registerTable(TABLE_ID);

        vm.stopPrank();
    }

    function test_RegisterTable_RevertIfAlreadyRegistered() public {
        vm.startPrank(owner);

        // Register first time
        dbManager.registerTable(TABLE_ID);

        // Try to register again
        vm.expectRevert(DatabaseManager.TableAlreadyRegistered.selector);
        dbManager.registerTable(TABLE_ID);

        vm.stopPrank();
    }

    function test_DeleteTable_Success() public {
        vm.startPrank(owner);

        // First register a table
        dbManager.registerTable(TABLE_ID);

        assertTrue(dbManager.isTableActive(TABLE_ID));

        // Delete the table
        vm.expectEmit();
        emit DatabaseManager.TableDeleted(TABLE_ID);
        dbManager.deleteTable(TABLE_ID);

        assertFalse(dbManager.isTableActive(TABLE_ID));
        vm.stopPrank();
    }

    function test_DeleteTable_RevertIfNotOwner() public {
        vm.prank(stranger);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                stranger,
                keccak256("OWNER_ROLE")
            )
        );
        dbManager.deleteTable(TABLE_ID);
    }

    function test_DeleteTable_RevertIfTableDoesNotExist() public {
        vm.prank(owner);

        // Try to delete a table that doesn't exist
        vm.expectRevert(DatabaseManager.TableDoesNotExist.selector);
        dbManager.deleteTable(TABLE_ID);
    }

    function test_RegisterQuery() public {
        vm.prank(owner);
        // First register a table
        dbManager.registerTable(TABLE_ID);
        // Anyone can register a query
        vm.expectEmit(true, true, false, true);
        emit DatabaseManager.NewQueryRegistered(QUERY_HASH, TABLE_ID, TEST_SQL);
        vm.prank(stranger);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);
        assertEq(dbManager.getTableForQuery(QUERY_HASH), TABLE_ID);
    }

    function test_RegisterQuery_RevertIfAlreadyRegistered() public {
        vm.startPrank(owner);
        // First register some tables
        dbManager.registerTable(TABLE_ID);
        dbManager.registerTable(TABLE_ID_2);

        vm.stopPrank();
        vm.startPrank(stranger);

        // Register first time
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);

        // Try to register again
        vm.expectRevert(DatabaseManager.QueryAlreadyRegistered.selector);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);

        // Try to register on a different table
        vm.expectRevert(DatabaseManager.QueryAlreadyRegistered.selector);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID_2, TEST_SQL);

        vm.stopPrank();
    }

    function test_IsQueryActive() public {
        vm.startPrank(owner);

        // Register table and query
        dbManager.registerTable(TABLE_ID);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);

        // Query should be active
        assertTrue(dbManager.isQueryActive(QUERY_HASH));

        // Delete table
        dbManager.deleteTable(TABLE_ID);

        // Query should no longer be active
        assertFalse(dbManager.isQueryActive(QUERY_HASH));

        // Re-activate the table
        dbManager.registerTable(TABLE_ID);

        // Query should now be active again
        assertTrue(dbManager.isQueryActive(QUERY_HASH));

        vm.stopPrank();
    }

    function test_GetTables() public {
        vm.startPrank(owner);

        // Register two tables
        dbManager.registerTable(TABLE_ID);
        dbManager.registerTable(TABLE_ID_2);

        // Get all tables
        bytes32[] memory tables = dbManager.getTables(0, 2);
        assertEq(tables.length, 2);
        assertEq(tables[0], TABLE_ID);
        assertEq(tables[1], TABLE_ID_2);

        // Get first table only
        tables = dbManager.getTables(0, 1);
        assertEq(tables.length, 1);
        assertEq(tables[0], TABLE_ID);

        // Get second table only
        tables = dbManager.getTables(1, 2);
        assertEq(tables.length, 1);
        assertEq(tables[0], TABLE_ID_2);

        // Delete a table
        dbManager.deleteTable(TABLE_ID);

        // Get remaining table
        tables = dbManager.getTables(0, 1);
        assertEq(tables.length, 1);
        assertEq(tables[0], TABLE_ID_2);

        vm.stopPrank();
    }

    function test_GetTables_RevertIfInvalidRange() public {
        vm.startPrank(owner);

        // Register a table
        dbManager.registerTable(TABLE_ID);

        // Try to get tables with invalid range
        vm.expectRevert(DatabaseManager.InvalidIndexRange.selector);
        dbManager.getTables(1, 0); // start > end

        vm.expectRevert(DatabaseManager.InvalidIndexRange.selector);
        dbManager.getTables(0, 2); // end > length

        vm.stopPrank();
    }

    function test_GetNumTables() public {
        vm.startPrank(owner);

        // Initially should have 0 tables
        assertEq(dbManager.getNumTables(), 0);

        // Register first table
        dbManager.registerTable(TABLE_ID);
        assertEq(dbManager.getNumTables(), 1);

        // Register second table
        dbManager.registerTable(TABLE_ID_2);
        assertEq(dbManager.getNumTables(), 2);

        // Delete first table
        dbManager.deleteTable(TABLE_ID);
        assertEq(dbManager.getNumTables(), 1);
        assertFalse(dbManager.isTableActive(TABLE_ID));
        assertTrue(dbManager.isTableActive(TABLE_ID_2));

        // Delete second table
        dbManager.deleteTable(TABLE_ID_2);
        assertEq(dbManager.getNumTables(), 0);
        assertFalse(dbManager.isTableActive(TABLE_ID));
        assertFalse(dbManager.isTableActive(TABLE_ID_2));

        vm.stopPrank();
    }

    function test_GetQueries() public {
        vm.startPrank(owner);

        // Register two tables
        dbManager.registerTable(TABLE_ID);
        dbManager.registerTable(TABLE_ID_2);

        // Register queries for first table
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);
        dbManager.registerQuery(QUERY_HASH_2, TABLE_ID, TEST_SQL_2);

        // Get all queries for first table
        bytes32[] memory queries = dbManager.getQueries(TABLE_ID, 0, 2);
        assertEq(queries.length, 2);
        assertEq(queries[0], QUERY_HASH);
        assertEq(queries[1], QUERY_HASH_2);

        // Get first query only
        queries = dbManager.getQueries(TABLE_ID, 0, 1);
        assertEq(queries.length, 1);
        assertEq(queries[0], QUERY_HASH);

        // Get second query only
        queries = dbManager.getQueries(TABLE_ID, 1, 2);
        assertEq(queries.length, 1);
        assertEq(queries[0], QUERY_HASH_2);

        vm.stopPrank();
    }

    function test_GetQueries_RevertIfInvalidRange() public {
        vm.startPrank(owner);

        // Register a table and query
        dbManager.registerTable(TABLE_ID);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);

        // Try to get queries with invalid range
        vm.expectRevert(DatabaseManager.InvalidIndexRange.selector);
        dbManager.getQueries(TABLE_ID, 1, 0); // start > end

        vm.expectRevert(DatabaseManager.InvalidIndexRange.selector);
        dbManager.getQueries(TABLE_ID, 0, 2); // end > length

        vm.expectRevert(DatabaseManager.InvalidIndexRange.selector);
        dbManager.getQueries(TABLE_ID, 1, 1); // end == length

        vm.stopPrank();
    }

    function test_GetNumQueries() public {
        vm.startPrank(owner);

        // Initially should have 0 queries for any table
        assertEq(dbManager.getNumQueries(TABLE_ID), 0);
        assertEq(dbManager.getNumQueries(TABLE_ID_2), 0);

        // Register first table and query
        dbManager.registerTable(TABLE_ID);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);
        assertEq(dbManager.getNumQueries(TABLE_ID), 1);
        assertEq(dbManager.getNumQueries(TABLE_ID_2), 0);

        // Register second query for first table
        dbManager.registerQuery(QUERY_HASH_2, TABLE_ID, TEST_SQL);
        assertEq(dbManager.getNumQueries(TABLE_ID), 2);
        assertEq(dbManager.getNumQueries(TABLE_ID_2), 0);

        // Register second table and query
        dbManager.registerTable(TABLE_ID_2);
        dbManager.registerQuery(QUERY_HASH_3, TABLE_ID_2, TEST_SQL);
        assertEq(dbManager.getNumQueries(TABLE_ID), 2);
        assertEq(dbManager.getNumQueries(TABLE_ID_2), 1);

        vm.stopPrank();
    }

    function test_DeleteQuery_Success() public {
        vm.startPrank(owner);
        // First register a table
        dbManager.registerTable(TABLE_ID);

        // Register a query
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);
        assertEq(dbManager.getNumQueries(TABLE_ID), 1);

        // Delete the query as owner
        vm.expectEmit();
        emit DatabaseManager.QueryDeleted(QUERY_HASH);
        dbManager.deleteQuery(QUERY_HASH);
        assertEq(dbManager.getNumQueries(TABLE_ID), 0);

        // Verify query is deleted
        assertEq(dbManager.getTableForQuery(QUERY_HASH), bytes32(0));

        vm.stopPrank();
    }

    function test_DeleteQuery_RevertIfNotOwner() public {
        vm.startPrank(owner);
        // First register a table
        dbManager.registerTable(TABLE_ID);
        vm.stopPrank();

        // Register a query
        vm.prank(stranger);
        dbManager.registerQuery(QUERY_HASH, TABLE_ID, TEST_SQL);

        // Try to delete query as non-owner
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                stranger,
                keccak256("OWNER_ROLE")
            )
        );
        dbManager.deleteQuery(QUERY_HASH);
    }

    function test_DeleteQuery_RevertIfQueryDoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert(DatabaseManager.QueryDoesNotExist.selector);
        dbManager.deleteQuery(QUERY_HASH);
    }
}
