// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {
    LPNRegistryV0,
    ContractAlreadyRegistered,
    QueryUnregistered,
    QueryBeforeIndexed,
    QueryAfterCurrentBlock,
    QueryInvalidRange,
    QueryGreaterThanMaxRange
} from "../src/LPNRegistryV0.sol";
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
        address indexed storageContract,
        address indexed client,
        uint256 mappingSlot,
        uint256 lengthSlot
    );

    event NewRequest(
        uint256 indexed requestId,
        address indexed storageContract,
        address indexed client,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock,
        OperationType op
    );

    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256 result
    );

    function register(address client_, uint256 mappingSlot, uint256 lengthSlot)
        private
    {
        vm.prank(client_);
        registry.register(storageContract, mappingSlot, lengthSlot);
    }

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
        emit NewRegistration(
            storageContract, address(client), mappingSlot, lengthSlot
        );

        register(address(client), mappingSlot, lengthSlot);
        assertEq(registry.indexStart(storageContract), block.number);
    }

    function testRegisterNotWhitelisted() public {
        uint256 mappingSlot = 1;
        uint256 lengthSlot = 2;

        vm.expectRevert(NotAuthorized.selector);
        vm.prank(address(client));
        registry.register(notWhitelisted, mappingSlot, lengthSlot);
    }

    function testRegisterContractAlreadyRegistered() public {
        uint256 mappingSlot = 1;
        uint256 lengthSlot = 2;

        vm.prank(address(client));
        registry.register(storageContract, mappingSlot, lengthSlot);

        vm.expectRevert(ContractAlreadyRegistered.selector);
        vm.prank(address(client));
        registry.register(storageContract, mappingSlot, lengthSlot);
    }

    function testRequest() public {
        register(address(client), 1, 2);
        bytes32 key = keccak256("key");
        uint256 startBlock = registry.indexStart(storageContract);
        uint256 endBlock = startBlock;
        OperationType op = OperationType.AVERAGE;

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            1, storageContract, address(client), key, startBlock, endBlock, op
        );

        vm.prank(address(client));
        uint256 requestId =
            registry.request(storageContract, key, startBlock, endBlock, op);

        assertEq(requestId, 1);
        assertEq(registry.requests(requestId), address(client));
    }

    function testRequestValidateQueryRange() public {
        bytes32 key = keccak256("key");
        uint256 startBlock;
        uint256 endBlock;
        OperationType op = OperationType.AVERAGE;

        // Test QueryUnregistered error
        vm.expectRevert(QueryUnregistered.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock, op);

        // Test QueryBeforeIndexed error
        register(address(client), 1, 2);
        startBlock = registry.indexStart(storageContract) - 1;
        endBlock = block.number;
        vm.expectRevert(QueryBeforeIndexed.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock, op);

        // Test QueryAfterCurrentBlock error
        startBlock = block.number;
        endBlock = block.number + 1;
        vm.expectRevert(QueryAfterCurrentBlock.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock, op);

        // Test QueryInvalidRange error
        startBlock = registry.indexStart(storageContract);
        endBlock = startBlock - 1;
        vm.expectRevert(QueryInvalidRange.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock, op);

        vm.roll(block.number + (registry.MAX_QUERY_RANGE() + 1));
        // Test QueryGreaterThanMaxRange error
        startBlock = registry.indexStart(storageContract);
        endBlock = startBlock + (registry.MAX_QUERY_RANGE() + 1);
        vm.expectRevert(QueryGreaterThanMaxRange.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock, op);
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
        uint256 startBlock = block.number;
        uint256 endBlock = block.number;
        OperationType op = OperationType.AVERAGE;
        uint256 result = 42;

        register(address(client), 1, 2);
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
