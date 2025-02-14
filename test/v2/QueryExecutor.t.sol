// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {QueryExecutorTestHelper} from
    "./test_helpers/QueryExecutorTestHelper.sol";
import {QueryExecutor} from "../../src/v2/QueryExecutor.sol";
import {
    QueryInput, QueryOutput
} from "../../src/v2/Groth16VerifierExtension.sol";
import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {FeeCollector} from "../../src/v2/FeeCollector.sol";

contract QueryExecutorTest is BaseTest {
    QueryExecutorTestHelper public executor;
    address public owner;
    address public router;
    address public dbManager;
    address public feeCollector;
    address public stranger;
    address public client;

    bytes32 constant QUERY_HASH = keccak256("query");
    uint256 constant TEST_START_BLOCK = 1000;
    uint256 constant TEST_END_BLOCK = 2000;
    uint256 FEE;

    bytes32[] PLACEHOLDERS;
    bytes32[] RESPONSE_DATA;

    function setUp() public {
        vm.chainId(1); // Ethereum mainnet

        owner = makeAddr("owner");
        router = makeAddr("router");
        dbManager = makeMock("dbManager");
        feeCollector = makeAddr("feeCollector");
        stranger = makeAddr("stranger");
        client = makeAddr("client");

        vm.prank(owner);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);

        vm.deal(router, 1 ether);
        vm.deal(stranger, 1 ether);

        PLACEHOLDERS = [
            bytes32(uint256(123)),
            bytes32(uint256(987)),
            bytes32(uint256(999))
        ];

        RESPONSE_DATA =
            [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))];

        FEE = executor.GAS_FEE();

        // Fast-forward to ensure all queries in range are valid
        vm.roll(TEST_START_BLOCK + executor.MAX_QUERY_RANGE() + 100);

        // Mock the dbManager to return true for all queries
        vm.mockCall(
            address(dbManager),
            abi.encodeWithSelector(DatabaseManager.isQueryActive.selector),
            abi.encode(true)
        );
    }

    function test_Constructor_SetsChainSpecificValues() public {
        // blockhash verification is enabled in tests
        assertTrue(executor.SUPPORTS_L1_BLOCKDATA());
        // Scroll mainnet
        imitateChain(534352);
        QueryExecutorTestHelper exec =
            new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertFalse(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.001 ether);
        // Scroll testnet
        imitateChain(534351);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertFalse(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.001 ether);
        // Polygon zkEVM mainnet
        imitateChain(1101);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertFalse(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.001 ether);
        // Ethereum mainnet
        imitateChain(1);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.01 ether);
        // Ethereum Holesky testnet
        imitateChain(17000);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.01 ether);
        // Mantle mainnet
        imitateChain(5000);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 4.0 ether);
        // Mantle testnet
        imitateChain(5003);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 4.0 ether);
        // Base mainnet
        imitateChain(8453);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.001 ether);
        // Base sepolia
        imitateChain(84532);
        exec = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        assertEq(exec.GAS_FEE(), 0.001 ether);
        // Unknown chain
        imitateChain(999999);
        vm.expectRevert(QueryExecutor.ChainNotSupported.selector);
        new QueryExecutorTestHelper(router, dbManager, feeCollector);
    }

    function test_Request_Success() public {
        vm.prank(router);
        uint256 id = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            10,
            100
        );

        // Check request data
        (address requestClient, QueryInput memory input) = executor.requests(id);
        assertEq(requestClient, client);
        assertEq(input.limit, 10);
        assertEq(input.offset, 100);
        assertEq(input.minBlockNumber, TEST_START_BLOCK);
        assertEq(input.maxBlockNumber, TEST_END_BLOCK);
        assertEq(input.blockHash, blockhash(block.number - 1));
        assertNotEq(input.blockHash, bytes32(0));
        assertEq(input.computationalHash, QUERY_HASH);
        assertEq(
            keccak256(abi.encode(input.userPlaceholders)),
            keccak256(abi.encode(PLACEHOLDERS))
        );

        // QE Address should be embedded in bytes [2:21] of the requestId
        address encodedAddress = address(bytes20(bytes32(id) << (8 * 2)));
        assertEq(address(executor), encodedAddress);

        // Entire fee should be forwarded to fee collector
        assertEq(feeCollector.balance, FEE);
        assertEq(address(executor).balance, 0);

        // Make a 2nd request
        vm.prank(router);
        uint256 id2 = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            10,
            100
        );

        // QE generates a new id for each request
        assertNotEq(id, id2);
    }

    function test_Request_RevertIf_NotCalledByRouter() public {
        vm.prank(stranger);
        vm.expectRevert(QueryExecutor.OnlyRouter.selector);
        executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );
    }

    function test_Request_RevertIf_InsufficientGasFee() public {
        vm.prank(router);
        vm.expectRevert(QueryExecutor.InsufficientGasFee.selector);
        executor.request{value: 0}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );
    }

    function test_Request_RevertIf_InvalidRange() public {
        vm.prank(router);
        vm.expectRevert(QueryExecutor.QueryInvalidRange.selector);
        executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_END_BLOCK,
            TEST_START_BLOCK,
            0,
            0
        );
    }

    function test_Request_RevertIf_ExceedsMaxRange() public {
        uint256 maxRange = executor.MAX_QUERY_RANGE();
        vm.startPrank(router);

        // Max range + 1 should revert
        vm.expectRevert(QueryExecutor.QueryGreaterThanMaxRange.selector);
        executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_START_BLOCK + maxRange,
            0,
            0
        );

        vm.stopPrank();
    }

    function test_Request_RevertIf_AfterLatestBlock() public {
        uint256 futureBlock = block.number + 1;
        vm.prank(router);
        vm.expectRevert(QueryExecutor.QueryAfterCurrentBlock.selector);
        executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            futureBlock,
            0,
            0
        );
    }

    function test_Request_RevertIf_QueryNotRegistered() public {
        // Mock the dbManager to return false for all queries
        vm.mockCall(
            address(dbManager),
            abi.encodeWithSelector(DatabaseManager.isQueryActive.selector),
            abi.encode(false)
        );

        vm.expectRevert(QueryExecutor.InvalidQuery.selector);
        vm.prank(router);

        executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );
    }

    function test_Respond_Success() public {
        // Make request
        vm.startPrank(router);
        uint256 id = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );

        // Verify request exists
        (address requestClient,) = executor.requests(id);
        assertEq(requestClient, client);

        (address returnedClient,) = executor.respond(id, RESPONSE_DATA);
        assertEq(returnedClient, client);

        // Verify request was deleted
        (requestClient,) = executor.requests(id);
        assertEq(requestClient, address(0));

        vm.stopPrank();
    }

    function test_Respond_RevertIf_NotCalledByRouter() public {
        vm.prank(router);
        uint256 id = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );

        vm.prank(stranger);
        vm.expectRevert(QueryExecutor.OnlyRouter.selector);
        executor.respond(id, RESPONSE_DATA);
    }

    function test_VerifyBlockhash_Success() public {
        // Ethereum mainnet
        imitateChain(1);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Scroll mainnet
        imitateChain(534352);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Scroll testnet
        imitateChain(534351);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Polygon zkEVM mainnet
        imitateChain(1101);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Ethereum Holesky testnet
        imitateChain(17000);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Mantle mainnet
        imitateChain(5000);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Mantle testnet
        imitateChain(5003);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Base mainnet
        imitateChain(8453);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Base sepolia
        imitateChain(84532);
        executor = new QueryExecutorTestHelper(router, dbManager, feeCollector);
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
    }
}
