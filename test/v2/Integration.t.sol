// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {DeployerTestHelper as Deployer} from
    "./test_helpers/DeployerTestHelper.sol";
import {LagrangeQueryRouter} from "../../src/v2/LagrangeQueryRouter.sol";
import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {QueryExecutor} from "../../src/v2/QueryExecutor.sol";
import {FeeCollector} from "../../src/v2/FeeCollector.sol";
import {ILPNClient} from "../../src/v2/interfaces/ILPNClient.sol";
import {
    QueryOutput,
    QueryErrorCode
} from "../../src/v2/Groth16VerifierExtension.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

/// @dev This test is used to test the E2E integration of the contracts
contract IntegrationTest is BaseTest {
    // Core protocol contracts
    LagrangeQueryRouter public router;
    DatabaseManager public dbManager;
    QueryExecutor public queryExecutor;
    FeeCollector public feeCollector;

    // Test accounts
    address public engMultisig;
    address public financeMultisig;
    address public stranger;
    address public client;

    // Test data
    bytes32 public constant TABLE_HASH = keccak256("test_table");
    string public constant TEST_SQL = "SELECT * FROM test_table";
    bytes32 public constant QUERY_HASH = keccak256(bytes(TEST_SQL));
    bytes32[] public PLACEHOLDERS;
    uint256 public constant START_BLOCK = 1000;
    uint256 public constant END_BLOCK = 2000;
    uint256 public constant GAS_FEE = 1 ether;
    QueryOutput public EXPECTED_OUTPUT;
    bytes32[] public RESPONSE_DATA;
    uint256 public requestId;

    function setUp() public {
        // Setup test accounts
        engMultisig = makeAddr("engMultisig");
        financeMultisig = makeAddr("financeMultisig");
        stranger = makeAddr("stranger");
        client = makeMock("client");

        vm.recordLogs();

        // Deploy all contracts using Deployer
        new Deployer(engMultisig, financeMultisig);

        // Get the last emitted event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory lastEntry = entries[entries.length - 1];

        // Parse emitted addresses from event
        (
            address routerProxy,
            address dbManagerProxy,
            address feeCollectorAddr,
            address queryExecutorAddr
        ) = abi.decode(lastEntry.data, (address, address, address, address));

        // Get contract instances from emitted addresses
        router = LagrangeQueryRouter(routerProxy);
        dbManager = DatabaseManager(dbManagerProxy);
        queryExecutor = QueryExecutor(queryExecutorAddr);
        feeCollector = FeeCollector(payable(feeCollectorAddr));

        // Setup test data
        PLACEHOLDERS = new bytes32[](2);
        PLACEHOLDERS[0] = bytes32(uint256(1));
        PLACEHOLDERS[1] = bytes32(uint256(2));
        EXPECTED_OUTPUT = QueryOutput({
            totalMatchedRows: 0,
            rows: new bytes[](0),
            error: QueryErrorCode.NoError
        });
        RESPONSE_DATA.push(bytes32(uint256(42)));

        // Fund client account
        vm.deal(client, 1 ether);

        // Mock client callback
        vm.mockCall(
            client, abi.encodeWithSelector(ILPNClient.lpnCallback.selector), ""
        );
    }

    function test_ContractIntegration() public {
        // Register table in DatabaseManager
        vm.prank(engMultisig);
        dbManager.registerTable(
            TABLE_HASH, address(0x123), 1, 100, "test_table", "schema"
        );

        // Register query
        vm.prank(stranger);
        dbManager.registerQuery(QUERY_HASH, TABLE_HASH, TEST_SQL);

        // Assert fee collector balance is 0
        assertEq(address(feeCollector).balance, 0);

        // Expect fee collector to receive GAS_FEE
        vm.expectEmit();
        emit FeeCollector.NativeReceived(address(queryExecutor), GAS_FEE);

        // Make request from client
        vm.prank(client);
        requestId = router.request{value: GAS_FEE}(
            QUERY_HASH, PLACEHOLDERS, START_BLOCK, END_BLOCK
        );

        // Expect client callback to be called
        vm.expectCall(
            client,
            abi.encodeWithSelector(
                ILPNClient.lpnCallback.selector, requestId, EXPECTED_OUTPUT
            )
        );

        // Submit response
        router.respond(requestId, RESPONSE_DATA);

        // Withdraw fee collector balance
        vm.prank(financeMultisig);
        feeCollector.withdrawNative(financeMultisig);
        assertEq(financeMultisig.balance, GAS_FEE);
    }
}
