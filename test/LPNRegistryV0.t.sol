// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";
import {NotAuthorized} from "../src/utils/OwnableWhitelist.sol";
import {ILPNRegistry, OperationType} from "../src/interfaces/ILPNRegistry.sol";
import {ILPNClient} from "../src/interfaces/ILPNClient.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockLPNClient is ILPNClient {
    uint256 public lastRequestId;
    uint256 public lastResult;

    function lpnCallback(uint256 _requestId, uint256 _result) external {
        lastRequestId = _requestId;
        lastResult = _result;
    }
}

contract LPNRegistryV0Test is Test {
    LPNRegistryV0 public registry;
    MockLPNClient client;

    address storageContract = makeAddr("storageContract");
    address notWhitelisted = makeAddr("notWhitelisted");

    address owner = makeAddr("owner");
    address notOwner = makeAddr("notOwner");

    event NewRegistration(
        address indexed client, uint256 mappingSlot, uint256 lengthSlot
    );

    event NewRequest(
        uint256 indexed requestId,
        address indexed account,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock,
        OperationType op
    );

    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256 result
    );

    function setUp() public {
        registry = new LPNRegistryV0();
        registry.initialize(owner);

        client = new MockLPNClient();
        hoax(owner);
        registry.toggleWhitelist(storageContract);
    }

    function testInitialize() public {
        registry = new LPNRegistryV0();
        registry.initialize(owner);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(notOwner);
    }

    function testRegister() public {
        uint256 mappingSlot = 1;
        uint256 lengthSlot = 2;

        vm.expectEmit(true, true, true, true);
        emit NewRegistration(storageContract, mappingSlot, lengthSlot);

        vm.prank(address(client));
        registry.register(storageContract, mappingSlot, lengthSlot);
    }

    function testRegisterNotWhitelisted() public {
        uint256 mappingSlot = 1;
        uint256 lengthSlot = 2;

        vm.expectRevert(NotAuthorized.selector);
        vm.prank(address(client));
        registry.register(notWhitelisted, mappingSlot, lengthSlot);
    }

    function testRequest() public {
        bytes32 key = keccak256("key");
        uint256 startBlock = 100;
        uint256 endBlock = 200;
        OperationType op = OperationType.AVERAGE;

        vm.expectEmit(true, true, true, true);
        emit NewRequest(1, storageContract, key, startBlock, endBlock, op);

        vm.prank(address(client));
        uint256 requestId =
            registry.request(storageContract, key, startBlock, endBlock, op);

        assertEq(requestId, 1);
        assertEq(registry.requests(requestId), address(client));
    }

    // function testRequestNotWhitelisted() public {
    //     bytes32 key = keccak256("key");
    //     uint256 startBlock = 100;
    //     uint256 endBlock = 200;
    //     OperationType op = OperationType.AVERAGE;
    //
    //     hoax(owner);
    //     registry.toggleWhitelist(address(client));
    //
    //     vm.expectRevert(NotAuthorized.selector);
    //     vm.prank(address(client));
    //     registry.request(storageContract, key, startBlock, endBlock, op);
    // }

    function testRespond() public {
        bytes32 key = keccak256("key");
        uint256 startBlock = 100;
        uint256 endBlock = 200;
        OperationType op = OperationType.AVERAGE;
        uint256 result = 42;

        vm.prank(address(client));
        uint256 requestId =
            registry.request(storageContract, key, startBlock, endBlock, op);

        vm.expectEmit(true, true, true, true);
        emit NewResponse(requestId, address(client), result);

        registry.respond(requestId, result);

        assertEq(client.lastRequestId(), requestId);
        assertEq(client.lastResult(), result);
        assertEq(registry.requests(requestId), address(0));
    }
}
