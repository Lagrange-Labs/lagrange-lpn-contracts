// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.t.sol";
import {TestERC20} from "../../src/mocks/TestERC20.sol";
import {DeepProvePayments} from "../../src/latoken/DeepProvePayments.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {console} from "forge-std/console.sol";

contract DeepProvePaymentsTest is BaseTest {
    DeepProvePayments public implementation;
    DeepProvePayments public escrow;
    TestERC20 public laToken;
    address public treasury;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy TestERC20 token
        laToken = new TestERC20();

        // Deploy DeepProvePayments implementation
        implementation = new DeepProvePayments(address(laToken), treasury);

        // Prepare initializer data
        bytes memory initData =
            abi.encodeWithSelector(DeepProvePayments.initialize.selector, owner);

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner, // admin
            initData
        );

        // Interact with DeepProvePayments via proxy
        escrow = DeepProvePayments(address(proxy));

        // Mint tokens to users
        laToken.mint(user1, 1000 ether);
        laToken.mint(user2, 1000 ether);
        laToken.mint(user3, 1000 ether);
        laToken.mint(treasury, 10000 ether);

        // Approve escrow to spend tokens
        vm.prank(user1);
        laToken.approve(address(escrow), type(uint256).max);
        vm.prank(user2);
        laToken.approve(address(escrow), type(uint256).max);
        vm.prank(user3);
        laToken.approve(address(escrow), type(uint256).max);
        vm.prank(treasury);
        laToken.approve(address(escrow), type(uint256).max);
    }

    // ------------------------------------------------------------
    //                    INITIALIZATION TESTS                    |
    // ------------------------------------------------------------

    function test_Version_Constant() public view {
        assertEq(escrow.VERSION(), "1.0.0");
    }

    function test_Constructor_RevertsWhen_LaTokenIsZero() public {
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        new DeepProvePayments(address(0), treasury);
    }

    function test_Constructor_RevertsWhen_TreasuryIsZero() public {
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        new DeepProvePayments(address(laToken), address(0));
    }

    function test_Initialize_Success() public view {
        assertEq(address(escrow.LA_TOKEN()), address(laToken));
        assertEq(escrow.TREASURY(), treasury);
        assertEq(escrow.owner(), owner);
    }

    function test_Initialize_RevertsWhen_CalledAgain() public {
        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        escrow.initialize(owner);
    }

    function test_Initialize_RevertsWhen_CalledOnImplementation() public {
        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(owner);
    }

    // ------------------------------------------------------------
    //                    AGREEMENT CREATION TESTS                |
    // ------------------------------------------------------------

    function test_CreateAgreement_Success() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DeepProvePayments.NewAgreement(
            user1,
            DeepProvePayments.EscrowAgreement({
                paymentAmount: 100 ether,
                rebateAmount: 10 ether,
                durationDays: 30,
                numRebates: 12,
                numRebatesClaimed: 0,
                activationDate: 0
            })
        );
        escrow.createAgreement(user1, params);

        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);
        assertEq(agreement.rebateAmount, 10 ether);
        assertEq(agreement.durationDays, 30);
        assertEq(agreement.numRebates, 12);
        assertEq(agreement.numRebatesClaimed, 0);
        assertEq(agreement.activationDate, 0);
    }

    function test_CreateAgreement_RevertsWhen_NotOwner() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, user1
            )
        );
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_UserIsZeroAddress() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        escrow.createAgreement(address(0), params);
    }

    function test_CreateAgreement_RevertsWhen_PaymentAmountIsZero() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 0,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_RebateAmountIsZero() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 0,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_DurationDaysIsZero() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 0,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidConfig.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_NumRebatesIsZero() public {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 0
        });

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidConfig.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_AgreementAlreadyExists() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.AgreementAlreadyExists.selector);
        escrow.createAgreement(user1, params);
    }

    // ------------------------------------------------------------
    //                    AGREEMENT ACTIVATION TESTS              |
    // ------------------------------------------------------------

    function test_ActivateAgreement_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        uint256 initialBalance = laToken.balanceOf(user1);
        uint256 initialContractBalance = laToken.balanceOf(address(escrow));

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit DeepProvePayments.AgreementActivated(user1);
        escrow.activateAgreement();

        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.activationDate, block.timestamp);
        assertEq(laToken.balanceOf(user1), initialBalance - 100 ether);
        assertEq(
            laToken.balanceOf(address(escrow)),
            initialContractBalance + 100 ether
        );
    }

    function test_ActivateAgreement_RevertsWhen_NoAgreementExists() public {
        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.InvalidAgreement.selector);
        escrow.activateAgreement();
    }

    function test_ActivateAgreement_RevertsWhen_AlreadyActivated() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user1);
        escrow.activateAgreement();

        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.AgreementAlreadyActivated.selector);
        escrow.activateAgreement();
    }

    function test_ActivateAgreement_RevertsWhen_InsufficientAllowance()
        public
    {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        // Revoke approval
        vm.prank(user1);
        laToken.approve(address(escrow), 0);

        vm.prank(user1);
        vm.expectRevert();
        escrow.activateAgreement();
    }

    function test_ActivateAgreement_RevertsWhen_InsufficientBalance() public {
        _createAgreementForUser(user1, 1000 ether, 10 ether, 30, 12);

        // Drain user's balance
        uint256 balance = laToken.balanceOf(user1);
        vm.prank(user1);
        laToken.transfer(address(0xdead), balance);

        vm.prank(user1);
        vm.expectRevert();
        escrow.activateAgreement();
    }

    // ------------------------------------------------------------
    //                        CLAIM TESTS                         |
    // ------------------------------------------------------------

    function test_Claim_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Fast forward 15 days (half the duration)
        vm.warp(block.timestamp + 15 days);

        uint256 initialBalance = laToken.balanceOf(user1);
        uint256 expectedClaim = 6 * 10 ether; // 6 rebates (half of 12)

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit DeepProvePayments.RebateClaimed(user1, expectedClaim);
        escrow.claimRebates();

        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.numRebatesClaimed, 6);
    }

    function test_Claim_FinalClaim_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Fast forward past the duration
        vm.warp(block.timestamp + 31 days);

        uint256 initialBalance = laToken.balanceOf(user1);
        uint256 expectedClaim = 12 * 10 ether; // All 12 rebates

        vm.prank(user1);
        escrow.claimRebates();

        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        // Agreement should be deleted
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);
    }

    function test_Claim_MultipleClaims_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        uint256 initialBalance = laToken.balanceOf(user1);

        // First claim after 10 days
        vm.warp(block.timestamp + 10 days);
        uint256 firstClaim = 4 * 10 ether; // 4 rebates

        vm.prank(user1);
        escrow.claimRebates();

        // Second claim after 20 days
        vm.warp(block.timestamp + 10 days);
        uint256 secondClaim = 4 * 10 ether; // 4 more rebates

        vm.prank(user1);
        escrow.claimRebates();

        // Final claim after 31 days
        vm.warp(block.timestamp + 11 days);
        uint256 finalClaim = 4 * 10 ether; // Remaining 4 rebates

        vm.prank(user1);
        escrow.claimRebates();

        // Agreement should be deleted
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);

        assertEq(
            laToken.balanceOf(user1),
            initialBalance + firstClaim + secondClaim + finalClaim
        );
    }

    function test_Claim_RevertsWhen_NoAgreementExists() public {
        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.InvalidAgreement.selector);
        escrow.claimRebates();
    }

    function test_Claim_RevertsWhen_AgreementNotActivated() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.InvalidAgreement.selector);
        escrow.claimRebates();
    }

    function test_Claim_RevertsWhen_NoClaimableRebates() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Try to claim immediately after activation
        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.NoClaimableRebates.selector);
        escrow.claimRebates();
    }

    function test_Claim_RevertsWhen_TreasuryTransferFails() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Drain contract balance
        uint256 balance = laToken.balanceOf(address(escrow));
        vm.prank(treasury);
        escrow.distribute(address(0xdead), balance);

        // Drain treasury balance
        uint256 treasuryBalance = laToken.balanceOf(treasury);
        vm.prank(treasury);
        laToken.transfer(address(0xdead), treasuryBalance);

        vm.warp(block.timestamp + 15 days);

        vm.prank(user1);
        vm.expectRevert();
        escrow.claimRebates();
    }

    // ------------------------------------------------------------
    //                      DISTRIBUTE TESTS                      |
    // ------------------------------------------------------------

    function test_Distribute_Success() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 100 ether;
        laToken.mint(address(escrow), amount);

        vm.prank(treasury);
        vm.expectEmit(true, true, true, true);
        emit DeepProvePayments.Distributed(recipient, amount);
        escrow.distribute(recipient, amount);

        assertEq(laToken.balanceOf(recipient), amount);
    }

    function test_Distribute_RevertsWhen_NotTreasury() public {
        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.OnlyTreasuryCanDistribute.selector);
        escrow.distribute(user1, 100 ether);
    }

    function test_Distribute_RevertsWhen_AmountIsZero() public {
        vm.prank(treasury);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.distribute(user1, 0);
    }

    function test_Distribute_RevertsWhen_RecipientIsZeroAddress() public {
        vm.prank(treasury);
        vm.expectRevert(DeepProvePayments.InvalidRecipient.selector);
        escrow.distribute(address(0), 100 ether);
    }

    function test_Distribute_RevertsWhen_TransferFails() public {
        // Try to distribute more than contract has
        vm.prank(treasury);
        uint256 balance = laToken.balanceOf(address(escrow));
        vm.expectRevert();
        escrow.distribute(user1, balance + 1);
    }

    // ------------------------------------------------------------
    //                    CANCEL AGREEMENT TESTS                  |
    // ------------------------------------------------------------

    function test_CancelAgreement_WhenNotActivated_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        // Verify agreement exists
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);
    }

    function test_CancelAgreement_WhenActivated_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Verify agreement exists and is activated
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);
        assertGt(agreement.activationDate, 0);

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);
    }

    function test_CancelAgreement_WithPendingClaims_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Advance time and claim some rebates
        vm.warp(block.timestamp + 15 days);
        vm.prank(user1);
        escrow.claimRebates();

        // Verify agreement still exists with some claims
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);
        assertGt(agreement.numRebatesClaimed, 0);

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);
    }

    function test_CancelAgreement_RevertsWhen_NotOwner() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, user1
            )
        );
        escrow.cancelAgreement(user1);
    }

    function test_CancelAgreement_RevertsWhen_AgreementDoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAgreement.selector);
        escrow.cancelAgreement(user1);
    }

    function test_CancelAgreement_AfterCancellation_UserCanCreateNewAgreement()
        public
    {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);

        // Create new agreement for same user
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: 150 ether,
            rebateAmount: 15 ether,
            durationDays: 45,
            numRebates: 18
        });

        vm.prank(owner);
        escrow.createAgreement(user1, params);

        // Verify new agreement exists
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 150 ether);
    }

    // ------------------------------------------------------------
    //                        VIEW TESTS                          |
    // ------------------------------------------------------------

    function test_GetEscrowAgreement_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);
        assertEq(agreement.rebateAmount, 10 ether);
        assertEq(agreement.durationDays, 30);
        assertEq(agreement.numRebates, 12);
        assertEq(agreement.numRebatesClaimed, 0);
        assertEq(agreement.activationDate, 0);
    }

    function test_GetEscrowAgreement_ReturnsEmptyForNonExistent() public view {
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);
    }

    function test_HasClaimableRebates_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        assertFalse(escrow.hasClaimableRebates(user1));

        vm.warp(block.timestamp + 15 days);
        assertTrue(escrow.hasClaimableRebates(user1));
    }

    function test_HasClaimableRebates_ReturnsFalseForNonExistent()
        public
        view
    {
        assertFalse(escrow.hasClaimableRebates(user1));
    }

    function test_GetCurrentClaimableAmount_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        assertEq(escrow.getCurrentClaimableAmount(user1), 0);

        vm.warp(block.timestamp + 15 days);
        assertEq(escrow.getCurrentClaimableAmount(user1), 6 * 10 ether);
    }

    function test_GetCurrentClaimableAmount_ReturnsZeroForNonExistent()
        public
        view
    {
        assertEq(escrow.getCurrentClaimableAmount(user1), 0);
    }

    function test_GetNextRebateClaimDate_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        uint256 expectedDate = block.timestamp + (30 days / 12); // First rebate
        assertEq(escrow.getNextRebateClaimDate(user1), expectedDate);

        // After duration ends, should return 0
        vm.warp(block.timestamp + 31 days);
        assertEq(escrow.getNextRebateClaimDate(user1), 0);
    }

    function test_GetNextRebateClaimDate_ReturnsZeroForNonExistent()
        public
        view
    {
        assertEq(escrow.getNextRebateClaimDate(user1), 0);
    }

    function test_GetNextRebateClaimDate_ReturnsZeroForNonActivated() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);
        assertEq(escrow.getNextRebateClaimDate(user1), 0);
    }

    // ------------------------------------------------------------
    //                    EDGE CASE TESTS                         |
    // ------------------------------------------------------------

    function test_Claim_WithContractBalanceAndTreasuryTransfer() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Remove most of the contract balance
        vm.prank(treasury);
        escrow.distribute(treasury, 99 ether);

        vm.warp(block.timestamp + 15 days);
        uint256 expectedClaim = 60 ether;

        assertEq(laToken.balanceOf(address(escrow)), 1 ether);
        assertEq(escrow.getCurrentClaimableAmount(user1), expectedClaim);

        uint256 initialBalance = laToken.balanceOf(user1);

        // Should use contract balance first, then treasury
        vm.prank(user1);
        escrow.claimRebates();
        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);
    }

    function test_Claim_WithOneDayDuration() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 1, 1);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        escrow.claimRebates();

        // Agreement should be deleted
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);
    }

    // ------------------------------------------------------------
    //                    TEST HELPER FUNCTIONS                   |
    // ------------------------------------------------------------

    function _createAgreementForUser(
        address user,
        uint88 paymentAmount,
        uint88 rebateAmount,
        uint16 durationDays,
        uint16 numRebates
    ) internal {
        DeepProvePayments.NewEscrowAgreementParams memory params =
        DeepProvePayments.NewEscrowAgreementParams({
            paymentAmount: paymentAmount,
            rebateAmount: rebateAmount,
            durationDays: durationDays,
            numRebates: numRebates
        });

        vm.prank(owner);
        escrow.createAgreement(user, params);
    }

    function _createAndActivateAgreement(
        address user,
        uint88 paymentAmount,
        uint88 rebateAmount,
        uint16 durationDays,
        uint16 numRebates
    ) internal {
        _createAgreementForUser(
            user, paymentAmount, rebateAmount, durationDays, numRebates
        );
        vm.prank(user);
        escrow.activateAgreement();
    }
}
