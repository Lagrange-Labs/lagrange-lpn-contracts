// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {LPNRegistryV1} from "../../src/v1/LPNRegistryV1.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {RegistrationManager} from "../../src/v1/RegistrationManager.sol";
import {IRegistrationManager} from
    "../../src/v1/interfaces/IRegistrationManager.sol";
import {QueryInput} from "../../src/v1/Groth16VerifierExtensions.sol";
import {QueryManager} from "../../src/v1/QueryManager.sol";
import {IQueryManager} from "../../src/v1/interfaces/IQueryManager.sol";

contract LPNRegistryV1Test is Test {
    LPNRegistryV1 public registry;
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

    function setUp() public {
        vm.chainId(1); // pretend we're on ETH mainnet (must set before calling registry.gasFee())

        owner = makeAddr("owner");
        stranger = makeAddr("stranger");
        user2 = makeAddr("user2");
        vm.deal(stranger, 1 ether);

        registry = new LPNRegistryV1();
        registry.initialize(owner);

        PLACEHOLDERS = [
            bytes32(uint256(123)),
            bytes32(uint256(987)),
            bytes32(uint256(999))
        ];
        FEE = registry.gasFee();

        vm.roll(TEST_START_BLOCK + registry.MAX_QUERY_RANGE() + 100); // fast-forward to ensure all queries in range are valid
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
            0 // proofBlock is 0 for L1
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
        assertEq(input.blockHash, 0); // TODO - only on ethereum
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

    function test_request_afterCurrentBlock_reverts() public {
        uint256 futureBlock = block.number + 1;
        vm.prank(stranger);
        vm.expectRevert(QueryManager.QueryAfterCurrentBlock.selector);
        registry.request{value: FEE}(
            QUERY_HASH, PLACEHOLDERS, TEST_START_BLOCK, futureBlock
        );
    }

    function test_respond_success() public {
        // to properly test this we need to either:
        //   a. mock the groth16 verifier library or ...
        //   b. generate a real, working proof for this test (preferred)
        vm.skip(true);
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
}
