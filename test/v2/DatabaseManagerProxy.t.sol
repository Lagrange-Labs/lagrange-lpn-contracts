// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {DatabaseManagerTest} from "./DatabaseManager.t.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev This runs all of the tests from DatabaseManagerTest, but uses a proxy contract instead
/// this way we test the contract directly, as well as it's functionality behind a proxy
contract DatabaseManagerProxyTest is DatabaseManagerTest {
    function setUp() public override {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");

        DatabaseManager dbManagerImplementation = new DatabaseManager();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(dbManagerImplementation),
            owner,
            abi.encodeWithSelector(DatabaseManager.initialize.selector, owner)
        );

        // cast the proxy to as the DatabaseManager contract, the base test suite will do the rest!
        dbManager = DatabaseManager(address(proxy));
    }
}
