// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {DeployerTestHelper} from "./test_helpers/DeployerTestHelper.sol";
import {Deployer} from "../../src/v2/Deployer.sol";
import {LagrangeQueryRouter} from "../../src/v2/LagrangeQueryRouter.sol";
import {DatabaseManager} from "../../src/v2/DatabaseManager.sol";
import {QueryExecutor} from "../../src/v2/QueryExecutor.sol";
import {FeeCollector} from "../../src/v2/FeeCollector.sol";
import {ILPNClient} from "../../src/v2/interfaces/ILPNClient.sol";
import {
    QueryOutput,
    QueryErrorCode
} from "../../src/v2/Groth16VerifierExtension.sol";
import {isInitialized, getProxyAdminOwner} from "../../src/utils/Proxy.sol";
import {Vm} from "forge-std/Vm.sol";

contract DeployerTest is BaseTest {
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
        new DeployerTestHelper(engMultisig, financeMultisig);

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
        assertTrue(isInitialized(address(router)));
        assertTrue(isInitialized(address(dbManager)));
        // Assert contracts point to eachother
        assertEq(
            address(router.getDefaultQueryExecutor()), address(queryExecutor)
        );
        assertEq(address(queryExecutor.getRouter()), address(router));
        assertEq(address(queryExecutor.getDBManager()), address(dbManager));
        assertEq(
            address(queryExecutor.getFeeCollector()), address(feeCollector)
        );
        // Assert proxy admins belong to eng multisig
        assertEq(getProxyAdminOwner(address(router)), engMultisig);
        assertEq(getProxyAdminOwner(address(dbManager)), engMultisig);
    }

    function test_Deployer_RevertsOnZeroEngMultisig() public {
        // Should revert when engineering multisig is zero address
        vm.expectRevert(Deployer.ZeroAddress.selector);
        new Deployer(address(0), financeMultisig);
    }

    function test_Deployer_RevertsOnZeroFinanceMultisig() public {
        // Should revert when finance multisig is zero address
        vm.expectRevert(Deployer.ZeroAddress.selector);
        new Deployer(engMultisig, address(0));
    }
}
