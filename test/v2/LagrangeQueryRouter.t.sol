// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseTest} from "./BaseTest.t.sol";
import {LagrangeQueryRouter} from "../../src/v2/LagrangeQueryRouter.sol";
import {IQueryExecutor} from "../../src/v2/interfaces/IQueryExecutor.sol";
import {ILPNClient} from "../../src/v2/interfaces/ILPNClient.sol";
import {
    QueryOutput,
    QueryErrorCode
} from "../../src/v2/Groth16VerifierExtension.sol";

import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/OwnableUpgradeable.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LagrangeQueryRouterTest is BaseTest {
    LagrangeQueryRouter public implementation;
    LagrangeQueryRouter public router;
    address public owner;
    address public executor;
    address public executor2;
    address public client;
    address public stranger;

    bytes32 constant QUERY_HASH = keccak256("test query");
    bytes32[] PLACEHOLDERS;
    uint256 constant START_BLOCK = 1000;
    uint256 constant END_BLOCK = 2000;
    uint256 constant GAS_FEE = 0.01 ether;

    uint256 public REQUEST_ID_1;
    uint256 public REQUEST_ID_2;

    QueryOutput public QUERY_OUTPUT;

    function setUp() public {
        owner = makeAddr("owner");
        executor = makeMock("executor");
        executor2 = makeMock("executor2");
        client = makeMock("client");
        stranger = makeAddr("stranger");

        // Setup test values
        PLACEHOLDERS = new bytes32[](3);
        PLACEHOLDERS[0] = bytes32(uint256(1));
        PLACEHOLDERS[1] = bytes32(uint256(2));
        PLACEHOLDERS[2] = bytes32(uint256(3));

        REQUEST_ID_1 = uint256(
            bytes32(
                bytes.concat(randomBytes(2), bytes20(executor), randomBytes(10))
            )
        );

        REQUEST_ID_2 = uint256(
            bytes32(
                bytes.concat(
                    randomBytes(2), bytes20(executor2), randomBytes(10)
                )
            )
        );

        QUERY_OUTPUT = QueryOutput({
            totalMatchedRows: 0,
            rows: new bytes[](0),
            error: QueryErrorCode.NoError
        });

        // Deploy implementation and proxy
        implementation = new LagrangeQueryRouter();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            abi.encodeWithSelector(
                LagrangeQueryRouter.initialize.selector, owner, executor
            )
        );

        // cast proxy to router contract
        router = LagrangeQueryRouter(address(proxy));

        // Fund accounts
        vm.deal(client, 1 ether);
        vm.deal(stranger, 1 ether);

        // Mock client contract to receive callbacks
        vm.mockCall(
            client, abi.encodeWithSelector(ILPNClient.lpnCallback.selector), ""
        );
        // Mock executor contracts to receive requests & make responses
        // Encode executor address in requestID, see QE contract for more details
        vm.mockCall(
            executor,
            abi.encodeWithSelector(IQueryExecutor.request.selector),
            abi.encode(REQUEST_ID_1)
        );
        vm.mockCall(
            executor,
            abi.encodeWithSelector(IQueryExecutor.respond.selector),
            abi.encode(client, QUERY_OUTPUT)
        );
        vm.mockCall(
            executor2,
            abi.encodeWithSelector(IQueryExecutor.request.selector),
            abi.encode(REQUEST_ID_2)
        );
        vm.mockCall(
            executor2,
            abi.encodeWithSelector(IQueryExecutor.respond.selector),
            abi.encode(client, QUERY_OUTPUT)
        );
    }

    function test_Initialize_Success() public view {
        assertEq(router.owner(), owner);
        assertEq(address(router.getDefaultQueryExecutor()), executor);
        assertTrue(router.getEnabledExecutors().length == 1);
    }

    function test_Initialize_RevertsIf_DuplicateAttempt() public {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        router.initialize(stranger, IQueryExecutor(executor));
    }

    function test_Initialize_RevertsIf_CalledDirectlyOnImplementation()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(Initializable.InvalidInitialization.selector)
        );
        implementation.initialize(stranger, IQueryExecutor(executor));
    }

    function test_Request_Aggregation_Success() public {
        vm.prank(client);
        vm.expectEmit();
        emit LagrangeQueryRouter.NewRequest(
            REQUEST_ID_1,
            QUERY_HASH,
            client,
            PLACEHOLDERS,
            START_BLOCK,
            END_BLOCK,
            GAS_FEE,
            block.number
        );
        router.request{value: GAS_FEE}(
            QUERY_HASH, PLACEHOLDERS, START_BLOCK, END_BLOCK
        );
    }

    function test_Request_LimitOffset_Success() public {
        vm.prank(client);
        vm.expectEmit();
        emit LagrangeQueryRouter.NewRequest(
            REQUEST_ID_1,
            QUERY_HASH,
            client,
            PLACEHOLDERS,
            START_BLOCK,
            END_BLOCK,
            GAS_FEE,
            block.number
        );
        router.request{value: GAS_FEE}(
            QUERY_HASH, PLACEHOLDERS, START_BLOCK, END_BLOCK, 10, 5
        );
    }

    function test_RequestTo_Success() public {
        // enable second executor
        vm.prank(owner);
        router.setExecutorEnabled(IQueryExecutor(executor2), true);

        // Make request
        vm.prank(client);
        vm.expectEmit();
        emit LagrangeQueryRouter.NewRequest(
            REQUEST_ID_2,
            QUERY_HASH,
            client,
            PLACEHOLDERS,
            START_BLOCK,
            END_BLOCK,
            GAS_FEE,
            block.number
        );
        uint256 requestId = router.requestTo{value: GAS_FEE}(
            IQueryExecutor(executor2),
            QUERY_HASH,
            PLACEHOLDERS,
            START_BLOCK,
            END_BLOCK,
            0,
            0
        );

        assertEq(requestId, REQUEST_ID_2);
    }

    function test_RequestTo_RevertsIf_ExecutorDisabled() public {
        vm.prank(client);
        vm.expectRevert(LagrangeQueryRouter.ExecutorNotEnabled.selector);
        router.requestTo{value: GAS_FEE}(
            IQueryExecutor(address(1)),
            QUERY_HASH,
            PLACEHOLDERS,
            START_BLOCK,
            END_BLOCK,
            0,
            0
        );
    }

    function test_Respond_Success() public {
        vm.expectEmit();
        emit LagrangeQueryRouter.NewResponse(REQUEST_ID_1, client, QUERY_OUTPUT);

        vm.expectCall(
            client,
            abi.encodeWithSelector(
                ILPNClient.lpnCallback.selector, REQUEST_ID_1, QUERY_OUTPUT
            )
        );

        router.respond(REQUEST_ID_1, new bytes32[](0));
    }

    function test_SetDefaultQueryExecutor_Success() public {
        assertTrue(router.getEnabledExecutors().length == 1);

        vm.prank(owner);
        router.setDefaultQueryExecutor(IQueryExecutor(executor2));

        assertEq(address(router.getDefaultQueryExecutor()), executor2);
        assertTrue(router.getEnabledExecutors().length == 2); // new executor is added to set

        // set back to original executor
        vm.prank(owner);
        router.setDefaultQueryExecutor(IQueryExecutor(executor));
        assertEq(address(router.getDefaultQueryExecutor()), executor);
        assertTrue(router.getEnabledExecutors().length == 2); // old set still valid
    }

    function test_SetDefaultQueryExecutor_RevertsIf_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector, stranger
            )
        );
        router.setDefaultQueryExecutor(IQueryExecutor(makeAddr("newExecutor")));
    }

    function test_SetExecutorEnabled_Success() public {
        address newExecutor = makeAddr("newExecutor");

        vm.startPrank(owner);
        uint256 initialLength = router.getEnabledExecutors().length;

        // Enable executor
        router.setExecutorEnabled(IQueryExecutor(newExecutor), true);
        assertEq(router.getEnabledExecutors().length, initialLength + 1);
        assertContains(router.getEnabledExecutors(), newExecutor);
        assertEq(address(router.getDefaultQueryExecutor()), executor); // default executor is unchanged

        // Disable executor
        router.setExecutorEnabled(IQueryExecutor(newExecutor), false);
        assertEq(router.getEnabledExecutors().length, initialLength);
        assertDoesNotContain(router.getEnabledExecutors(), newExecutor);

        vm.stopPrank();
    }

    function test_SetExecutorEnabled_RevertsIf_DefaultDisabled() public {
        vm.prank(owner);
        vm.expectRevert(
            LagrangeQueryRouter.CannotDisableDefaultExecutor.selector
        );
        router.setExecutorEnabled(IQueryExecutor(executor), false);
    }
}
