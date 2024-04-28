// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    LPNRegistryV0,
    ContractAlreadyRegistered,
    QueryUnregistered,
    QueryBeforeIndexed,
    QueryAfterCurrentBlock,
    QueryInvalidRange,
    QueryGreaterThanMaxRange,
    InsufficientGasFee
} from "../src/LPNRegistryV0.sol";
import {NotAuthorized} from "../src/utils/OwnableWhitelist.sol";
import {ILPNRegistry} from "../src/interfaces/ILPNRegistry.sol";
import {ILPNClient} from "../src/interfaces/ILPNClient.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Groth16Verifier} from "../src/Groth16Verifier.sol";
import {
    ETH_MAINNET,
    BASE_MAINNET,
    OP_STACK_L1_BLOCK_PREDEPLOY_ADDR
} from "../src/utils/Constants.sol";
import {IOptimismL1Block} from "../src/interfaces/IOptimismL1Block.sol";
import {Ownable} from "solady/auth/Ownable.sol";

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

    address storageContract = 0x0101010101010101010101010101010101010101;
    address otherStorageContract = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;

    address notWhitelisted = makeAddr("notWhitelisted");

    address owner = makeAddr("owner");
    address notOwner = makeAddr("notOwner");
    uint256 gasFee;
    uint256 offset = 3;

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
        uint256 offset,
        uint256 gasFee,
        uint256 proofBlock
    );

    event NewResponse(
        uint256 indexed requestId, address indexed client, uint256[] results
    );

    function register(
        address storageContract_,
        uint256 mappingSlot,
        uint256 lengthSlot
    ) private {
        vm.prank(address(client));
        registry.register(storageContract_, mappingSlot, lengthSlot);
    }

    function setUp() public {
        vm.chainId(ETH_MAINNET);
        registry = new LPNRegistryV0();
        registry.initialize(owner);

        client = new MockLPNClient();
        hoax(owner);
        registry.toggleWhitelist(storageContract);
        hoax(owner);
        registry.toggleWhitelist(otherStorageContract);

        gasFee = registry.gasFee();
        vm.deal(address(client), 10 ether);
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

        register(storageContract, mappingSlot, lengthSlot);
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
        uint256 blockNumber = 12345;
        uint256 proofBlock = 0;
        bytes32 blockHash = 0;
        vm.roll(blockNumber);
        register(storageContract, 1, 2);
        bytes32 key = keccak256("key");
        uint256 startBlock = block.number;
        uint256 endBlock = startBlock;

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            1,
            storageContract,
            address(client),
            key,
            startBlock,
            endBlock,
            offset,
            gasFee,
            proofBlock
        );

        vm.prank(address(client));
        uint256 requestId = registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        (
            address storageContract_,
            address key_,
            address client_,
            uint256 startBlock_,
            uint256 endBlock_,
            bytes32 blockhash_
        ) = registry.queries(requestId);

        assertEq(requestId, 1);

        assertEq(storageContract_, storageContract);
        assertEq(key_, address(uint160(uint256(key))));
        assertEq(client_, address(client));
        assertEq(startBlock_, startBlock);
        assertEq(endBlock_, endBlock);
        assertEq(blockhash_, blockHash);
    }

    function testRequestOP() public {
        uint256 l2Block = 12345;
        uint256 l1Block = 123;
        bytes32 l1BlockHash = bytes32("567");
        vm.chainId(BASE_MAINNET);
        vm.roll(l2Block);
        bytes32 key = keccak256("key");
        uint256 startBlock = l1Block;
        uint256 endBlock = startBlock;

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            1,
            storageContract,
            address(client),
            key,
            startBlock,
            endBlock,
            offset,
            gasFee,
            l1Block
        );

        vm.mockCall(
            OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
            abi.encodeWithSelector(IOptimismL1Block.number.selector),
            abi.encode(l1Block)
        );
        vm.mockCall(
            OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
            abi.encodeWithSelector(IOptimismL1Block.hash.selector),
            abi.encode(l1BlockHash)
        );
        vm.prank(address(client));
        uint256 requestId = registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        (
            address storageContract_,
            address key_,
            address client_,
            uint256 startBlock_,
            uint256 endBlock_,
            bytes32 blockhash_
        ) = registry.queries(requestId);

        assertEq(requestId, 1);

        assertEq(storageContract_, storageContract);
        assertEq(key_, address(uint160(uint256(key))));
        assertEq(client_, address(client));
        assertEq(startBlock_, startBlock);
        assertEq(endBlock_, endBlock);
        assertEq(blockhash_, l1BlockHash);
    }

    function testRequestValidateQueryRange() public {
        bytes32 key = keccak256("key");
        uint256 startBlock;
        uint256 endBlock;

        // Test QueryUnregistered error
        vm.expectRevert(QueryUnregistered.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        // Test QueryBeforeIndexed error
        register(storageContract, 1, 2);
        startBlock = registry.indexStart(storageContract) - 1;
        endBlock = block.number;
        vm.expectRevert(QueryBeforeIndexed.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        // Test QueryAfterCurrentBlock error
        startBlock = block.number;
        endBlock = block.number + 1;
        vm.expectRevert(QueryAfterCurrentBlock.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        // Test QueryInvalidRange error
        startBlock = registry.indexStart(storageContract);
        endBlock = startBlock - 1;
        vm.expectRevert(QueryInvalidRange.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        vm.roll(block.number + (registry.MAX_QUERY_RANGE() + 1));
        // Test QueryGreaterThanMaxRange error
        startBlock = registry.indexStart(storageContract);
        endBlock = startBlock + (registry.MAX_QUERY_RANGE() + 1);
        vm.expectRevert(QueryGreaterThanMaxRange.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );
    }

    function testRequestOPValidateQueryRange() public {
        vm.chainId(BASE_MAINNET);
        bytes32 key = keccak256("key");
        uint256 l1Block = 12345;

        vm.mockCall(
            OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
            abi.encodeWithSelector(IOptimismL1Block.number.selector),
            abi.encode(l1Block)
        );
        // vm.roll(12345);
        uint256 startBlock;
        uint256 endBlock;

        // Test QueryAfterCurrentBlock error
        startBlock = l1Block;
        endBlock = l1Block + 1;
        vm.expectRevert(QueryAfterCurrentBlock.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        // Test QueryInvalidRange error
        endBlock = startBlock - 1;
        vm.expectRevert(QueryInvalidRange.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );

        vm.mockCall(
            OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
            abi.encodeWithSelector(IOptimismL1Block.number.selector),
            abi.encode(l1Block + (registry.MAX_QUERY_RANGE() + 1))
        );
        // Test QueryGreaterThanMaxRange error
        endBlock = startBlock + (registry.MAX_QUERY_RANGE() + 1);
        vm.expectRevert(QueryGreaterThanMaxRange.selector);
        vm.prank(address(client));
        registry.request{value: gasFee}(
            storageContract, key, startBlock, endBlock, offset
        );
    }

    function testRequestInsufficientGas() public {
        bytes32 key = keccak256("key");
        uint256 startBlock;
        uint256 endBlock;

        assertEq(registry.ETH_GAS_FEE(), 0.05 ether);
        assertEq(registry.OP_GAS_FEE(), 0.00015 ether);

        vm.expectRevert(InsufficientGasFee.selector);
        vm.prank(address(client));
        registry.request{value: 0}(
            storageContract, key, startBlock, endBlock, offset
        );

        vm.expectRevert(InsufficientGasFee.selector);
        vm.prank(address(client));
        registry.request{value: 0.049 ether}(
            storageContract, key, startBlock, endBlock, offset
        );

        vm.chainId(BASE_MAINNET);
        vm.expectRevert(InsufficientGasFee.selector);
        vm.prank(address(client));
        registry.request{value: 0.00014 ether}(
            storageContract, key, startBlock, endBlock, offset
        );
    }

    function testRespond() public {
        uint256 startBlock = 19662380;
        uint256 endBlock = 19662380;
        uint256 proofBlock = 19662458;
        address userAddress = 0x8B58f7C312406d7C6A5D01898f0C5aef31eE51a7;
        bytes32 key = bytes32(uint256(uint160(userAddress)));

        uint8[1] memory nftIds = [0];

        uint256[] memory expectedResults = new uint256[](5);
        for (uint256 i = 0; i < nftIds.length; i++) {
            expectedResults[i] = nftIds[i];
        }

        vm.roll(startBlock);
        register(otherStorageContract, 1, 2);
        vm.roll(proofBlock);

        vm.prank(address(client));
        uint256 requestId = registry.request{value: gasFee}(
            otherStorageContract, key, startBlock, endBlock, offset
        );

        bytes32[] memory proof = readProof("/test/full_proof.bin");
        // TODO: Figure out how to mock block hash
        vm.expectRevert(
            bytes(
                "The parsed block hash must be equal to the expected one in query."
            )
        );

        // vm.expectEmit(true, true, true, true);
        // emit NewResponse(requestId, address(client), expectedResults);
        registry.respond(requestId, proof, proofBlock);

        // (,, address clientAddress,,,) = registry.queries(requestId);

        // assertEq(client.lastRequestId(), requestId);
        // for (uint256 i = 0; i < expectedResults.length; i++) {
        // assertEq(client.lastResult(i), expectedResults[i]);
        // }
        // assertEq(clientAddress, address(0));
    }

    function testRespondOP() public {
        vm.chainId(BASE_MAINNET);
        uint256 startBlock = 19662380;
        uint256 endBlock = 19662380;
        uint256 proofBlock = 19662458;
        bytes32 l1BlockHash =
            0x1753f6b036b3367cfacbdd088a1418ad57461c7e0d9929c79a7db2110e5480fd;
        address userAddress = 0x8B58f7C312406d7C6A5D01898f0C5aef31eE51a7;
        bytes32 key = bytes32(uint256(uint160(userAddress)));

        uint16[5] memory nftIds = [8782, 8538, 2760, 4567, 4319];

        uint256[] memory expectedResults = new uint256[](5);
        for (uint256 i = 0; i < nftIds.length; i++) {
            expectedResults[i] = nftIds[i];
        }

        vm.roll(proofBlock);

        vm.mockCall(
            OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
            abi.encodeWithSelector(IOptimismL1Block.number.selector),
            abi.encode(proofBlock)
        );
        vm.mockCall(
            OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
            abi.encodeWithSelector(IOptimismL1Block.hash.selector),
            abi.encode(l1BlockHash)
        );

        vm.prank(address(client));
        uint256 requestId = registry.request{value: gasFee}(
            otherStorageContract, key, startBlock, endBlock, offset
        );

        bytes32[] memory proof = readProof("/test/full_proof.bin");

        vm.expectEmit(true, true, true, true);
        emit NewResponse(requestId, address(client), expectedResults);
        registry.respond(requestId, proof, 0);

        (,, address clientAddress,,,) = registry.queries(requestId);

        assertEq(client.lastRequestId(), requestId);
        for (uint256 i = 0; i < expectedResults.length; i++) {
            assertEq(client.lastResult(i), expectedResults[i]);
        }
        assertEq(clientAddress, address(0));
    }

    function testWithdrawFees() public {
        uint256 registryBalance = 1 ether;
        vm.deal(address(registry), registryBalance);

        uint256 balanceBefore = owner.balance;
        hoax(owner);
        registry.withdrawFees();
        uint256 balanceAfter = owner.balance;

        assertEq(address(registry).balance, 0);
        assertEq(balanceBefore + registryBalance, balanceAfter);
    }

    function testWithdrawFeesOnlyOwner() public {
        uint256 registryBalance = 1 ether;
        vm.deal(address(registry), registryBalance);

        uint256 balanceBefore = notOwner.balance;
        hoax(notOwner, 0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.withdrawFees();
        uint256 balanceAfter = notOwner.balance;

        assertEq(address(registry).balance, registryBalance);
        assertEq(balanceBefore, balanceAfter);
    }

    function readProof(string memory proofFile)
        private
        view
        returns (bytes32[] memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, proofFile);

        bytes memory proofData = vm.readFileBinary(path);
        // Calculate the number of bytes32 elements needed
        uint256 numBytes32 = (proofData.length + 31) / 32;

        // Create a bytes32[] array to hold the proof data
        bytes32[] memory proof = new bytes32[](numBytes32);

        // Copy the proof data into the bytes32[] array
        for (uint256 i = 0; i < numBytes32; i++) {
            bytes32 chunk = bytesToBytes32(proofData, i * 32);
            proof[i] = chunk;
        }
        return proof;
    }

    function bytesToBytes32(bytes memory b, uint256 offset_)
        private
        pure
        returns (bytes32)
    {
        bytes32 out;

        for (uint256 i = 0; i < 32; i++) {
            if (offset_ + i >= b.length) {
                out |= bytes32(0x00 & 0xFF) >> (i * 8);
            } else {
                out |= bytes32(b[offset_ + i] & 0xFF) >> (i * 8);
            }
        }
        return out;
    }
}
