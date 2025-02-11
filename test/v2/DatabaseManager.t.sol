// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {BaseTest} from "./BaseTest.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DatabaseManagerTest is BaseTest {
    DatabaseManager public dbManager;
    address public owner;
    address public stranger;

    // Test data
    string public constant TEST_SQL = "SELECT * FROM test_table";
    bytes32 public constant TEST_QUERY_HASH = keccak256(bytes(TEST_SQL));
    bytes32 public constant TEST_TABLE_HASH = keccak256("test_table");

    function setUp() public virtual {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");

        dbManager = new DatabaseManager();
        dbManager.initialize(owner);
    }

    function test_Initialize() public {
        assertTrue(dbManager.hasRole(keccak256("OWNER_ROLE"), owner));
        assertFalse(dbManager.hasRole(keccak256("OWNER_ROLE"), stranger));
    }

    function test_RegisterTable_Success() public {
        vm.prank(owner);

        vm.expectEmit();
        emit DatabaseManager.NewTableRegistration(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );

        assertTrue(dbManager.tables(TEST_TABLE_HASH));
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
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );

        vm.stopPrank();
    }

    function test_RegisterTable_RevertIfAlreadyRegistered() public {
        vm.startPrank(owner);

        // Register first time
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );

        // Try to register again
        vm.expectRevert(DatabaseManager.TableAlreadyRegistered.selector);
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );

        vm.stopPrank();
    }

    function test_DeleteTable_Success() public {
        vm.startPrank(owner);

        // First register a table
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );

        assertTrue(dbManager.tables(TEST_TABLE_HASH));

        // Delete the table
        vm.expectEmit();
        emit DatabaseManager.TableDeleted(TEST_TABLE_HASH);
        dbManager.deleteTable(TEST_TABLE_HASH);

        assertFalse(dbManager.tables(TEST_TABLE_HASH));
        vm.stopPrank();
    }

    function test_DeleteTable_RevertIfNotOwner() public {
        vm.startPrank(stranger);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                stranger,
                keccak256("OWNER_ROLE")
            )
        );
        dbManager.deleteTable(TEST_TABLE_HASH);

        vm.stopPrank();
    }

    function test_RegisterQuery() public {
        vm.prank(owner);
        // First register a table
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );
        // Anyone can register a query
        vm.expectEmit(true, true, false, true);
        emit DatabaseManager.NewQueryRegistration(
            TEST_QUERY_HASH, TEST_TABLE_HASH, TEST_SQL
        );
        vm.prank(stranger);
        dbManager.registerQuery(TEST_QUERY_HASH, TEST_TABLE_HASH, TEST_SQL);
        assertEq(dbManager.queries(TEST_QUERY_HASH), TEST_TABLE_HASH);
    }

    function test_RegisterQuery_RevertIfAlreadyRegistered() public {
        vm.prank(owner);
        // First register a table
        dbManager.registerTable(
            TEST_TABLE_HASH, address(0x123), 1, 100, "test_table", TEST_SQL
        );

        vm.startPrank(stranger);

        // Register first time
        dbManager.registerQuery(TEST_QUERY_HASH, TEST_TABLE_HASH, TEST_SQL);

        // Try to register again
        vm.expectRevert(DatabaseManager.QueryAlreadyRegistered.selector);
        dbManager.registerQuery(TEST_QUERY_HASH, TEST_TABLE_HASH, TEST_SQL);

        vm.stopPrank();
    }
}
