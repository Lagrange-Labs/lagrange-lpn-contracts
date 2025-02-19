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

contract DeployerTest is BaseTest {
    bytes32 INITIALIZED_SLOT =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

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
    }

    /// @notice this tests that the Deployment tx configures the contracts correctly
    function test_Deployer() public view {
        // Assert all contracts are owned by appropriate multisigs
        assertEq(router.owner(), engMultisig);
        assertTrue(dbManager.hasRole(keccak256("OWNER_ROLE"), engMultisig));
        assertEq(queryExecutor.owner(), engMultisig);
        assertEq(feeCollector.owner(), financeMultisig);
        // Assert contracts are initialized
        assertTrue(uint256(vm.load(address(router), INITIALIZED_SLOT)) == 1);
        assertTrue(uint256(vm.load(address(dbManager), INITIALIZED_SLOT)) == 1);
        // Assert contracts point to eachother
        assertEq(
            address(router.getDefaultQueryExecutor()), address(queryExecutor)
        );
        assertEq(address(queryExecutor.router()), address(router));
        assertEq(address(queryExecutor.dbManager()), address(dbManager));
        assertEq(address(queryExecutor.feeCollector()), address(feeCollector));
    }
}
