// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {
    OwnableWhitelist, NotAuthorized
} from "../src/utils/OwnableWhitelist.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockOwnableWhitelist is OwnableWhitelist, Initializable {
    function initialize(address owner) external initializer {
        OwnableWhitelist._initialize(owner);
    }

    function onlyWhitelistedFunction() public view onlyWhitelist(msg.sender) {}
}

contract OwnableWhitelistTest is Test {
    MockOwnableWhitelist whitelist;
    address owner = makeAddr("owner");
    address client1 = makeAddr("client1");
    address client2 = makeAddr("client2");

    function setUp() public {
        whitelist = new MockOwnableWhitelist();
        whitelist.initialize(owner);
    }

    function testInitialization() public view {
        assertEq(whitelist.owner(), owner);
    }

    function testToggleWhitelist() public {
        assertEq(whitelist.whitelist(client1), false);

        startHoax(owner);
        vm.expectEmit(true, true, true, true);
        emit OwnableWhitelist.Whitelisted(client1, true);
        whitelist.toggleWhitelist(client1);
        assertEq(whitelist.whitelist(client1), true);

        vm.expectEmit(true, true, true, true);
        emit OwnableWhitelist.Whitelisted(client1, false);
        whitelist.toggleWhitelist(client1);
        assertEq(whitelist.whitelist(client1), false);
    }

    function testOnlyOwnerCanToggleWhitelist() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(client1);
        whitelist.toggleWhitelist(client1);
    }

    function testOnlyWhitelistedCanAccess() public {
        vm.expectRevert(NotAuthorized.selector);
        vm.prank(client1);
        whitelist.onlyWhitelistedFunction();

        vm.prank(owner);
        whitelist.toggleWhitelist(client1);
        vm.prank(client1);
        whitelist.onlyWhitelistedFunction();
    }

    function testAddToWhitelist() public {
        assertEq(whitelist.whitelist(client1), false);
        assertEq(whitelist.whitelist(client2), false);
        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        hoax(owner);
        vm.expectEmit(true, true, true, true);
        emit OwnableWhitelist.BatchWhitelisted(clients, true);

        whitelist.addToWhitelist(clients);

        assertEq(whitelist.whitelist(client1), true);
        assertEq(whitelist.whitelist(client2), true);
    }

    function testAddToWhitelist_RevertIfNotOwner() public {
        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        vm.expectRevert(Ownable.Unauthorized.selector);
        whitelist.addToWhitelist(clients);
    }

    function testRemoveFromWhitelist() public {
        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        hoax(owner);
        whitelist.addToWhitelist(clients);

        hoax(owner);
        vm.expectEmit(true, true, true, true);
        emit OwnableWhitelist.BatchWhitelisted(clients, false);

        whitelist.removeFromWhitelist(clients);

        assertEq(whitelist.whitelist(client1), false);
        assertEq(whitelist.whitelist(client2), false);
    }

    function testRemoveFromWhitelist_RevertIfNotOwner() public {
        address[] memory clients = new address[](2);
        clients[0] = client1;
        clients[1] = client2;

        vm.expectRevert(Ownable.Unauthorized.selector);
        whitelist.removeFromWhitelist(clients);
    }
}
