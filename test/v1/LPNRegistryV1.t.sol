// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {LPNRegistryV1TestHelper} from
    "../../src/v1/test_helpers/LPNRegistryV1TestHelper.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {RegistrationManager} from "../../src/v1/RegistrationManager.sol";
import {IRegistrationManager} from
    "../../src/v1/interfaces/IRegistrationManager.sol";
import {
    QueryInput, QueryOutput
} from "../../src/v1/Groth16VerifierExtension.sol";
import {QueryManager} from "../../src/v1/QueryManager.sol";
import {IQueryManager} from "../../src/v1/interfaces/IQueryManager.sol";
import {ILPNClientV1} from "../../src/v1/interfaces/ILPNClientV1.sol";

contract LPNRegistryV1Test is BaseTest {
    LPNRegistryV1TestHelper public registry;
    address public owner;
    address public stranger;
    address public user2;

    bytes32 constant HASH = keccak256("test_table");
    address constant CONTRACT_ADDR =
        address(0x1234567890123456789012345678901234567890);
    uint96 constant CHAIN_ID = 1;
    uint256 constant GENESIS_BLOCK = 100;
    string constant NAME = "Test Table";
    string constant SCHEMA = "id INT, name STRING";

    bytes32 constant QUERY_HASH = keccak256("query");
    string constant SQL = "SELECT * FROM table";

    bytes32[] PLACEHOLDERS; // = new bytes32[](0);
    uint256 FEE;
    uint256 constant TEST_START_BLOCK = 1000;
    uint256 constant TEST_END_BLOCK = 2000;

    bytes32[] responseData = [
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32(),
        randomBytes32()
    ];

    function setUp() public {
        vm.chainId(CHAIN_ID); // pretend we're on ETH mainnet

        owner = makeAddr("owner");
        stranger = makeAddr("stranger");
        user2 = makeAddr("user2");
        vm.deal(stranger, 1 ether);
        vm.deal(CONTRACT_ADDR, 1 ether);

        registry = new LPNRegistryV1TestHelper();
        registry.initialize(owner);

        PLACEHOLDERS = [
            bytes32(uint256(123)),
            bytes32(uint256(987)),
            bytes32(uint256(999))
        ];
        FEE = registry.GAS_FEE();

        vm.roll(TEST_START_BLOCK + registry.MAX_QUERY_RANGE() + 100); // fast-forward to ensure all queries in range are valid

        // Mock the contract to receive callbacks
        vm.etch(CONTRACT_ADDR, hex"00"); // set code at the address so it can receive calls
        vm.mockCall(
            CONTRACT_ADDR,
            abi.encodeWithSelector(ILPNClientV1.lpnCallback.selector), // this will succeed with any input as long as the function sig is correct
            ""
        );
    }

    function test_constructor_setsChainSpecificValues_success() public {
        // blockhash verification is enabled in tests
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        // Scroll mainnet
        imitateChain(534352);
        registry = new LPNRegistryV1TestHelper();
        assertFalse(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.001 ether);
        // Scroll testnet
        imitateChain(534351);
        registry = new LPNRegistryV1TestHelper();
        assertFalse(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.001 ether);
        // Polygon zkEVM mainnet
        imitateChain(1101);
        registry = new LPNRegistryV1TestHelper();
        assertFalse(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.001 ether);
        // Ethereum mainnet
        imitateChain(1);
        registry = new LPNRegistryV1TestHelper();
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.01 ether);
        // Ethereum Holesky testnet
        imitateChain(17000);
        registry = new LPNRegistryV1TestHelper();
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.01 ether);
        // Mantle mainnet
        imitateChain(5000);
        registry = new LPNRegistryV1TestHelper();
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 4.0 ether);
        // Mantle testnet
        imitateChain(5003);
        registry = new LPNRegistryV1TestHelper();
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 4.0 ether);
        // Base mainnet
        imitateChain(8453);
        registry = new LPNRegistryV1TestHelper();
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.001 ether);
        // Base sepolia
        imitateChain(84532);
        registry = new LPNRegistryV1TestHelper();
        assertTrue(registry.SUPPORTS_L1_BLOCKDATA());
        assertEq(registry.GAS_FEE(), 0.001 ether);
    }

    function test_initialize_duplicateAttempt_reverts() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(stranger);
    }

    function test_registerTable_success() public {
        assertFalse(registry.tables(HASH));
        vm.prank(owner);
        vm.expectEmit();
        emit IRegistrationManager.NewTableRegistration(
            HASH, CONTRACT_ADDR, CHAIN_ID, GENESIS_BLOCK, NAME, SCHEMA
        );
        registry.registerTable(
            HASH, CONTRACT_ADDR, CHAIN_ID, GENESIS_BLOCK, NAME, SCHEMA
        );
        assertTrue(registry.tables(HASH));
    }

    function test_registerTable_whenCalledByNonOwner_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.registerTable(
            HASH, CONTRACT_ADDR, CHAIN_ID, GENESIS_BLOCK, NAME, SCHEMA
        );
    }

    function test_registerTable_duplicateHash_reverts() public {
        vm.startPrank(owner);
        registry.registerTable(
            HASH, CONTRACT_ADDR, CHAIN_ID, GENESIS_BLOCK, NAME, SCHEMA
        );
        vm.expectRevert(RegistrationManager.TableAlreadyRegistered.selector);
        registry.registerTable(
            HASH, CONTRACT_ADDR, CHAIN_ID, GENESIS_BLOCK, NAME, SCHEMA
        );
    }

    function test_withdrawFees_success() public {
        vm.deal(address(registry), 1 ether);
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        registry.withdrawFees();
        assertEq(address(registry).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
    }

    function test_withdrawFees_whenCalledByNonOwner_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.withdrawFees();
    }

    function test_registerQuery_success() public {
        assertFalse(registry.queries(QUERY_HASH));
        vm.prank(stranger); // anyone can register a query
        vm.expectEmit();
        emit IRegistrationManager.NewQueryRegistration(QUERY_HASH, HASH, SQL);
        registry.registerQuery(QUERY_HASH, HASH, SQL);
        assertTrue(registry.queries(QUERY_HASH));
    }

    function test_registerQuery_duplicateQueryHash_reverts() public {
        registry.registerQuery(QUERY_HASH, HASH, SQL);
        vm.expectRevert(RegistrationManager.QueryAlreadyRegistered.selector);
        registry.registerQuery(QUERY_HASH, "", "");
    }

    function test_registerQuery_nonexistentTable_reverts() public {
        vm.skip(true); // TODO - requires contract changes
        bytes32 nonexistentTableHash = bytes32(uint256(1234));
        // vm.expectRevert(RegistrationManager.TableNotRegistered.selector);
        registry.registerQuery(QUERY_HASH, nonexistentTableHash, SQL);
    }

    function test_request_success() public {
        vm.startPrank(stranger); // queries can be made by anyone
        // check log
        vm.expectEmit();
        emit IQueryManager.NewRequest(
            1, // expected ID
            QUERY_HASH,
            stranger,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_END_BLOCK,
            FEE,
            block.number - 1
        );
        // do the thing
        uint256 id = registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, TEST_END_BLOCK
        );
        // check request data
        (address client, QueryInput memory input) = registry.requests(id);
        assertEq(client, stranger);
        assertEq(input.limit, 0);
        assertEq(input.offset, 0);
        assertEq(input.minBlockNumber, TEST_START_BLOCK);
        assertEq(input.maxBlockNumber, TEST_END_BLOCK);
        assertEq(input.blockHash, blockhash(block.number - 1));
        assertNotEq(input.blockHash, bytes32(0));
        assertEq(input.computationalHash, QUERY_HASH);
        assertEq(
            keccak256(abi.encode(input.userPlaceholders)),
            keccak256(abi.encode(PLACEHOLDERS))
        );
        // make duplicate request
        uint256 id2 = registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, TEST_END_BLOCK
        );
        assertNotEq(id, id2);
        // make request with explicit limit / offset (this is a different function)
        uint256 id3 = registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, TEST_END_BLOCK, 10, 100
        );
        (, input) = registry.requests(id3);
        assertEq(input.limit, 10);
        assertEq(input.offset, 100);
    }

    function test_request_insufficientGasFee_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(QueryManager.InsufficientGasFee.selector);
        registry.request{value: 0}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, TEST_END_BLOCK
        );
    }

    function test_request_invalidRange_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(QueryManager.QueryInvalidRange.selector);
        registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_END_BLOCK, TEST_START_BLOCK
        );
    }

    function test_request_exceedsMaxRange_reverts() public {
        vm.skip(true); // TODO - maxRange not enforced correctly
        uint256 maxRange = registry.MAX_QUERY_RANGE();
        vm.startPrank(stranger);
        // max range should succeed
        registry.request{value: FEE}(
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_START_BLOCK + maxRange
        );
        // max range + 1 should revert
        vm.expectRevert(QueryManager.QueryGreaterThanMaxRange.selector);
        registry.request{value: FEE}(
            QUERY_HASH,
            PLACEHOLDERS,
            TEST_START_BLOCK,
            TEST_START_BLOCK + maxRange + 1
        );
    }

    function test_request_afterLatestBlock_reverts() public {
        uint256 futureBlock = block.number;
        vm.prank(stranger);
        vm.expectRevert(QueryManager.QueryAfterCurrentBlock.selector);
        registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, futureBlock
        );
    }

    /// @dev this test relies on a mocked processQuery() function in LPNRegistryV1TestHelper
    function test_respond_success() public {
        // make a request first
        vm.startPrank(CONTRACT_ADDR);
        uint256 id = registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, TEST_END_BLOCK
        );
        QueryOutput memory expectedOutput;
        // check log
        vm.expectEmit();
        emit IQueryManager.NewResponse(id, CONTRACT_ADDR, expectedOutput);
        // check callback
        vm.expectCall(
            CONTRACT_ADDR,
            abi.encodeWithSelector(
                ILPNClientV1.lpnCallback.selector, id, expectedOutput
            )
        );
        // send the response
        registry.respond(id, responseData, 100);
    }

    function test_respond_invalidRequestId_reverts() public {
        // New error required
        vm.skip(true);
        uint256 invalidRequestId = 9999; // Non-existent requestId
        bytes32[] memory data;
        uint256 blockNumber = block.number;
        vm.prank(stranger);
        // vm.expectRevert(QueryManager.UnknownRequestID.selector); // DNE
        registry.respond(invalidRequestId, data, blockNumber);
    }

    function test_verifyBlockhash_success() public {
        // Ethereum mainnet
        imitateChain(1);
        registry = new LPNRegistryV1TestHelper();
        vm.expectRevert(QueryManager.BlockhashMismatch.selector);
        registry.verifyBlockhash(randomBytes32(), randomBytes32());
        // Scroll mainnet
        imitateChain(534352);
        registry = new LPNRegistryV1TestHelper();
        registry.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Scroll testnet
        imitateChain(534351);
        registry = new LPNRegistryV1TestHelper();
        registry.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Polygon zkEVM mainnet
        imitateChain(1101);
        registry = new LPNRegistryV1TestHelper();
        registry.verifyBlockhash(randomBytes32(), randomBytes32()); // should not revert
        // Ethereum Holesky testnet
        imitateChain(17000);
        registry = new LPNRegistryV1TestHelper();
        vm.expectRevert(QueryManager.BlockhashMismatch.selector);
        registry.verifyBlockhash(randomBytes32(), randomBytes32());
        // Mantle mainnet
        imitateChain(5000);
        registry = new LPNRegistryV1TestHelper();
        vm.expectRevert(QueryManager.BlockhashMismatch.selector);
        registry.verifyBlockhash(randomBytes32(), randomBytes32());
        // Mantle testnet
        imitateChain(5003);
        registry = new LPNRegistryV1TestHelper();
        vm.expectRevert(QueryManager.BlockhashMismatch.selector);
        registry.verifyBlockhash(randomBytes32(), randomBytes32());
        // Base mainnet
        imitateChain(8453);
        registry = new LPNRegistryV1TestHelper();
        vm.expectRevert(QueryManager.BlockhashMismatch.selector);
        registry.verifyBlockhash(randomBytes32(), randomBytes32());
        // Base sepolia
        imitateChain(84532);
        registry = new LPNRegistryV1TestHelper();
        vm.expectRevert(QueryManager.BlockhashMismatch.selector);
        registry.verifyBlockhash(randomBytes32(), randomBytes32());
    }
}
