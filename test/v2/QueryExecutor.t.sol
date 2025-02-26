// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {QueryExecutorTestHelper} from
    "./test_helpers/QueryExecutorTestHelper.sol";
import {QueryExecutor} from "../../src/v2/QueryExecutor.sol";
import {
    QueryInput,
    QueryOutput,
    QueryErrorCode
} from "../../src/v2/Groth16VerifierExtension.sol";
import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {FeeCollector} from "../../src/v2/FeeCollector.sol";
import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {console} from "forge-std/console.sol";

contract QueryExecutorTest is BaseTest {
    QueryExecutorTestHelper public executor;
    address public owner;
    address public router;
    address public dbManager;
    address payable public feeCollector;
    address public stranger;
    address public client;

    bytes32 constant QUERY_HASH = keccak256("query");
    uint256 constant TEST_START_BLOCK = 1000;
    uint256 constant TEST_END_BLOCK = 2000;
    uint256 FEE;

    bytes32[] PLACEHOLDERS;
    bytes32[] RESPONSE_DATA;

    uint32 public constant CALLBACK_GAS_LIMIT = 100_000;

    QueryExecutor.Config public config;

    function setUp() public {
        vm.chainId(1); // Ethereum mainnet

        owner = makeAddr("owner");
        router = makeAddr("router");
        dbManager = makeMock("dbManager");
        feeCollector = payable(makeAddr("feeCollector"));
        stranger = makeAddr("stranger");
        client = makeAddr("client");

        config = QueryExecutor.Config({
            maxQueryRange: 50_000,
            baseFeePercentage: 100,
            verificationGas: 0,
            protocolFeePPT: 0,
            queryPricePerBlock: 0,
            protocolFeeFixed: 0
        });

        vm.prank(owner);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );

        vm.deal(router, 1 ether);
        vm.deal(stranger, 1 ether);

        PLACEHOLDERS = [
            bytes32(uint256(123)),
            bytes32(uint256(987)),
            bytes32(uint256(999))
        ];

        RESPONSE_DATA =
            [bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))];

        // Fast-forward to ensure all queries in range are valid
        vm.roll(TEST_START_BLOCK + executor.getConfig().maxQueryRange + 100);

        // Mock the dbManager to return true for all queries
        vm.mockCall(
            address(dbManager),
            abi.encodeWithSelector(DatabaseManager.isQueryActive.selector),
            abi.encode(true)
        );

        // getFee() relies on the basefee, so we must set it to non-zero
        vm.fee(1 gwei);

        FEE = executor.getFee(
            QUERY_HASH,
            CALLBACK_GAS_LIMIT,
            TEST_END_BLOCK - TEST_START_BLOCK + 1
        );
    }

    function test_Constructor_SetsChainSpecificValues() public {
        // blockhash verification is enabled in tests
        assertTrue(executor.SUPPORTS_L1_BLOCKDATA());
        // Scroll mainnet
        imitateChain(534352);
        QueryExecutorTestHelper exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertFalse(exec.SUPPORTS_L1_BLOCKDATA());
        // Scroll testnet
        imitateChain(534351);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertFalse(exec.SUPPORTS_L1_BLOCKDATA());
        // Polygon zkEVM mainnet
        imitateChain(1101);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertFalse(exec.SUPPORTS_L1_BLOCKDATA());
        // Ethereum mainnet
        imitateChain(1);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        // Ethereum Holesky testnet
        imitateChain(17000);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        // Mantle mainnet
        imitateChain(5000);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        // Mantle testnet
        imitateChain(5003);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        // Base mainnet
        imitateChain(8453);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
        // Base sepolia
        imitateChain(84532);
        exec = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        assertTrue(exec.SUPPORTS_L1_BLOCKDATA());
    }

    function test_Request_Success() public {
        vm.prank(router);

        // Expect NewRequest event
        vm.expectEmit(false, true, true, true); // IDs are pseudo-random so don't test it
        emit QueryExecutor.NewRequest(
            0,
            QUERY_HASH,
            client,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            10,
            100,
            FEE,
            block.number
        );

        uint256 id = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            CALLBACK_GAS_LIMIT,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            10,
            100
        );

        // Check request data
        QueryExecutor.QueryRequest memory request = executor.getRequest(id);
        assertEq(request.client, client);
        assertEq(request.callbackGasLimit, CALLBACK_GAS_LIMIT);
        assertEq(request.input.limit, 10);
        assertEq(request.input.offset, 100);
        assertEq(request.input.minBlockNumber, TEST_START_BLOCK);
        assertEq(request.input.maxBlockNumber, TEST_END_BLOCK);
        assertEq(request.input.blockHash, blockhash(block.number - 1));
        assertNotEq(request.input.blockHash, bytes32(0));
        assertEq(request.input.computationalHash, QUERY_HASH);
        assertEq(
            keccak256(abi.encode(request.input.userPlaceholders)),
            keccak256(abi.encode(PLACEHOLDERS))
        );

        // Entire fee should be forwarded to fee collector
        assertEq(feeCollector.balance, FEE);
        assertEq(address(executor).balance, 0);

        // Make a 2nd request
        vm.prank(router);
        uint256 id2 = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            CALLBACK_GAS_LIMIT,
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
            CALLBACK_GAS_LIMIT,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );
    }

    function test_Request_RevertIf_InsufficientFee() public {
        vm.prank(router);
        vm.expectRevert(QueryExecutor.InsufficientFee.selector);
        executor.request{value: 0}(
            client,
            QUERY_HASH,
            CALLBACK_GAS_LIMIT,
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
            CALLBACK_GAS_LIMIT,
            PLACEHOLDERS,
            TEST_END_BLOCK,
            TEST_START_BLOCK,
            0,
            0
        );
    }

    function test_Request_RevertIf_ExceedsMaxRange() public {
        uint256 maxRange = executor.getConfig().maxQueryRange;
        vm.startPrank(router);

        // Max range + 1 should revert
        vm.expectRevert(QueryExecutor.QueryGreaterThanMaxRange.selector);
        executor.request{value: FEE}(
            client,
            QUERY_HASH,
            CALLBACK_GAS_LIMIT,
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
            CALLBACK_GAS_LIMIT,
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
            CALLBACK_GAS_LIMIT,
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
            CALLBACK_GAS_LIMIT,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            0,
            0
        );

        // Verify request exists
        QueryExecutor.QueryRequest memory request = executor.getRequest(id);
        assertEq(request.client, client);

        // Expect NewResponse event
        vm.expectEmit(true, true, true, true);
        emit QueryExecutor.NewResponse(
            id,
            client,
            QueryOutput({
                totalMatchedRows: 0,
                rows: new bytes[](0),
                error: QueryErrorCode.NoError
            })
        );

        (address returnedClient, uint256 gasLimit,) =
            executor.respond(id, RESPONSE_DATA);
        assertEq(returnedClient, client);
        assertEq(gasLimit, CALLBACK_GAS_LIMIT);

        // Verify request was deleted
        request = executor.getRequest(id);
        assertEq(request.client, address(0));

        vm.stopPrank();
    }

    function test_Respond_RevertIf_NotCalledByRouter() public {
        vm.prank(router);
        uint256 id = executor.request{value: FEE}(
            client,
            QUERY_HASH,
            CALLBACK_GAS_LIMIT,
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

    function test_SetConfig_Success() public {
        QueryExecutor.Config memory newConfig = QueryExecutor.Config({
            maxQueryRange: 50_000,
            baseFeePercentage: 999,
            verificationGas: 123_456,
            protocolFeePPT: 22,
            queryPricePerBlock: 9_876,
            protocolFeeFixed: 123
        });

        vm.prank(owner);
        executor.setConfig(newConfig);

        assertEq(abi.encode(executor.getConfig()), abi.encode(newConfig));
    }

    function test_SetConfig_RevertIf_NotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.setConfig(config);
    }

    function test_GetFee_BaseFeePercentage_IncreasesFee_Success() public {
        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Increase baseFeePercentage
        QueryExecutor.Config memory newConfig = config;
        newConfig.baseFeePercentage = 200; // Double the percentage
        vm.prank(owner);
        executor.setConfig(newConfig);

        // Fee should double
        uint256 newFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertEq(newFee, oldFee * 2);
    }

    function test_GetFee_VerificationGas_IncreasesFee_Success() public {
        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Set verification gas
        QueryExecutor.Config memory newConfig = config;
        newConfig.verificationGas = uint24(CALLBACK_GAS_LIMIT); // this should double the price
        vm.prank(owner);
        executor.setConfig(newConfig);

        // Fee should double
        uint256 newFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertEq(newFee, oldFee * 2);
    }

    function test_GetFee_ProtocolFeePPT_IncreasesFee_Success() public {
        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Set protocol fee PPT to 100 (10%)
        QueryExecutor.Config memory newConfig = config;
        newConfig.protocolFeePPT = 100;
        vm.prank(owner);
        executor.setConfig(newConfig);

        // Fee should increase by 10%
        uint256 newFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertEq(newFee, (oldFee * 11) / 10);
    }

    function test_GetFee_QueryPricePerBlock_IncreasesFee_Success() public {
        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Set query price per block
        QueryExecutor.Config memory newConfig = config;
        newConfig.queryPricePerBlock = 3;
        vm.prank(owner);
        executor.setConfig(newConfig);

        // Fee should increase by (blockRange * queryPricePerBlock * 1 gwei)
        uint256 newFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertEq(newFee, oldFee + (100 * 3 * 1 gwei));
    }

    function test_GetFee_ProtocolFeeFixed_IncreasesFee_Success() public {
        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Set fixed protocol fee
        QueryExecutor.Config memory newConfig = config;
        newConfig.protocolFeeFixed = 1234;
        vm.prank(owner);
        executor.setConfig(newConfig);

        // Fee should increase by fixed amount
        uint256 newFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertEq(newFee, oldFee + 1234);
    }

    function test_GetFee_QueryRange_IncreasesFee_Success() public {
        // Set prices to only charge for the query (no gas charge)
        QueryExecutor.Config memory newConfig = config;
        newConfig.baseFeePercentage = 0;
        newConfig.queryPricePerBlock = 1;
        vm.prank(owner);
        executor.setConfig(newConfig);

        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Fee should double
        uint256 newFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 200);
        assertEq(newFee, oldFee * 2);
    }

    function test_GetFee_CallbackGasLimit_IncreasesFee_Success() public view {
        uint256 oldFee = executor.getFee(QUERY_HASH, CALLBACK_GAS_LIMIT, 100);
        assertGt(oldFee, 0);

        // Fee should double
        uint256 newFee =
            executor.getFee(QUERY_HASH, 2 * CALLBACK_GAS_LIMIT, 200);
        assertEq(newFee, oldFee * 2);
    }

    function test_VerifyBlockhash_Success() public {
        // Ethereum mainnet
        imitateChain(1);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Scroll mainnet
        imitateChain(534352);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        executor.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Scroll testnet
        imitateChain(534351);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        executor.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Polygon zkEVM mainnet
        imitateChain(1101);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        executor.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Ethereum Holesky testnet
        imitateChain(17000);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Mantle mainnet
        imitateChain(5000);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Mantle testnet
        imitateChain(5003);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Base mainnet
        imitateChain(8453);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
        // Base sepolia
        imitateChain(84532);
        executor = new QueryExecutorTestHelper(
            owner, router, dbManager, feeCollector, config
        );
        vm.expectRevert(QueryExecutor.BlockhashMismatch.selector);
        executor.verifyBlockhash(randomBytes32(), randomBytes32());
    }
}
