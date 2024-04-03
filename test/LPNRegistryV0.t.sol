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
import {ILPNRegistry} from "../src/interfaces/ILPNRegistry.sol";
import {ILPNClient} from "../src/interfaces/ILPNClient.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Groth16Verifier} from "../src/Groth16Verifier.sol";

contract MockLPNClient is ILPNClient {
    uint256 public lastRequestId;
    uint256[] public lastResult;

    function lpnCallback(uint256 _requestId, uint256[] calldata _results)
        external
    {
        lastRequestId = _requestId;
        lastResult = _results;
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
        uint256 endBlock
    );

    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256[] results
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

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            1, storageContract, address(client), key, startBlock, endBlock
        );

        vm.prank(address(client));
        uint256 requestId =
            registry.request(storageContract, key, startBlock, endBlock);

        (,, address clientAddress,,,) = registry.queries(requestId);

        assertEq(requestId, 1);
        assertEq(clientAddress, address(client));
    }

    function testRequestValidateQueryRange() public {
        bytes32 key = keccak256("key");
        uint256 startBlock;
        uint256 endBlock;

        // Test QueryUnregistered error
        vm.expectRevert(QueryUnregistered.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock);

        // Test QueryBeforeIndexed error
        register(address(client), 1, 2);
        startBlock = registry.indexStart(storageContract) - 1;
        endBlock = block.number;
        vm.expectRevert(QueryBeforeIndexed.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock);

        // Test QueryAfterCurrentBlock error
        startBlock = block.number;
        endBlock = block.number + 1;
        vm.expectRevert(QueryAfterCurrentBlock.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock);

        // Test QueryInvalidRange error
        startBlock = registry.indexStart(storageContract);
        endBlock = startBlock - 1;
        vm.expectRevert(QueryInvalidRange.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock);

        vm.roll(block.number + (registry.MAX_QUERY_RANGE() + 1));
        // Test QueryGreaterThanMaxRange error
        startBlock = registry.indexStart(storageContract);
        endBlock = startBlock + (registry.MAX_QUERY_RANGE() + 1);
        vm.expectRevert(QueryGreaterThanMaxRange.selector);
        vm.prank(address(client));
        registry.request(storageContract, key, startBlock, endBlock);
    }

    function testRespond() public {
        // TODO: Fix with verification
        bytes32 key = keccak256("key");
        uint256 startBlock = block.number;
        uint256 endBlock = block.number;
        uint256[] memory results = new uint256[](3);
        uint256 one = uint256(1);
        uint256[3] memory inputs = [one, one, one];
        bytes32[] memory data = new bytes32[](13);
        for (uint256 i = 0; i < 13; i++) {
            data[i] = bytes32(one);
        }

        for (uint256 i = 0; i < 3; i++) {
            results[i] = one;
        }

        register(address(client), 1, 2);
        vm.prank(address(client));
        uint256 requestId =
            registry.request(storageContract, key, startBlock, endBlock);

        vm.expectEmit(true, true, true, true);
        emit NewResponse(requestId, address(client), results);

        registry.respond(requestId, data);

        (,, address clientAddress,,,) = registry.queries(requestId);

        assertEq(client.lastRequestId(), requestId);
        assertEq(client.lastResult(2), inputs[2]);
        assertEq(clientAddress, address(0));
    }
}
