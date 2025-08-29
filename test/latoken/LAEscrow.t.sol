// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.t.sol";
import {TestERC20} from "../../src/mocks/TestERC20.sol";
import {LAEscrow} from "../../src/latoken/LAEscrow.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract LAEscrowTest is BaseTest {
    LAEscrow public implementation;
    LAEscrow public escrow;
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

        // Deploy LAEscrow implementation
        implementation = new LAEscrow(address(laToken), treasury);

        // Prepare initializer data
        bytes memory initData =
            abi.encodeWithSelector(LAEscrow.initialize.selector, owner);

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner, // admin
            initData
        );

        // Interact with LAEscrow via proxy
        escrow = LAEscrow(address(proxy));

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
        vm.expectRevert(LAEscrow.ZeroAddress.selector);
        new LAEscrow(address(0), treasury);
    }

    function test_Constructor_RevertsWhen_TreasuryIsZero() public {
        vm.expectRevert(LAEscrow.ZeroAddress.selector);
        new LAEscrow(address(laToken), address(0));
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
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit LAEscrow.NewAgreement(
            user1,
            LAEscrow.EscrowAgreement({
                paymentAmount: 100 ether,
                rebateAmount: 10 ether,
                durationDays: 30,
                numRebates: 12,
                numRebatesClaimed: 0,
                activationDate: 0
            })
        );
        escrow.createAgreement(user1, params);

        LAEscrow.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);
        assertEq(agreement.rebateAmount, 10 ether);
        assertEq(agreement.durationDays, 30);
        assertEq(agreement.numRebates, 12);
        assertEq(agreement.numRebatesClaimed, 0);
        assertEq(agreement.activationDate, 0);
    }

    function test_CreateAgreement_RevertsWhen_NotOwner() public {
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
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
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(LAEscrow.ZeroAddress.selector);
        escrow.createAgreement(address(0), params);
    }

    function test_CreateAgreement_RevertsWhen_PaymentAmountIsZero() public {
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 0,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(LAEscrow.InvalidAmount.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_RebateAmountIsZero() public {
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 0,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(LAEscrow.InvalidAmount.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_DurationDaysIsZero() public {
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 0,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(LAEscrow.InvalidConfig.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_NumRebatesIsZero() public {
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 0
        });

        vm.prank(owner);
        vm.expectRevert(LAEscrow.InvalidConfig.selector);
        escrow.createAgreement(user1, params);
    }

    function test_CreateAgreement_RevertsWhen_AgreementAlreadyExists() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
            paymentAmount: 100 ether,
            rebateAmount: 10 ether,
            durationDays: 30,
            numRebates: 12
        });

        vm.prank(owner);
        vm.expectRevert(LAEscrow.AgreementAlreadyExists.selector);
        escrow.createAgreement(user1, params);
    }

    // ------------------------------------------------------------
    //                    AGREEMENT ACTIVATION TESTS              |
    // ------------------------------------------------------------

    function test_ActivateAgreementForUser_ByTreasury_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        uint256 initialUserBalance = laToken.balanceOf(user1);
        uint256 initialTreasuryBalance = laToken.balanceOf(treasury);
        uint256 initialContractBalance = laToken.balanceOf(address(escrow));

        vm.prank(treasury);
        vm.expectEmit(true, true, true, true);
        emit LAEscrow.AgreementActivated(user1);
        escrow.activateAgreement(user1);

        LAEscrow.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.activationDate, block.timestamp);
        // User balance unchanged; tokens are taken from caller (treasury)
        assertEq(laToken.balanceOf(user1), initialUserBalance);
        assertEq(
            laToken.balanceOf(treasury), initialTreasuryBalance - 100 ether
        );
        assertEq(
            laToken.balanceOf(address(escrow)),
            initialContractBalance + 100 ether
        );
    }

    function test_ActivateAgreementForUser_RevertsWhen_UnauthorizedCaller()
        public
    {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user2);
        vm.expectRevert(LAEscrow.OnlyLagrangeCanActivate.selector);
        escrow.activateAgreement(user1);
    }

    function test_ActivateAgreementForUser_ByOwner_Success() public {
        _createAgreementForUser(user2, 200 ether, 20 ether, 60, 6);

        // Give owner funds and allowance because tokens are pulled from caller
        laToken.mint(owner, 1000 ether);
        vm.prank(owner);
        laToken.approve(address(escrow), type(uint256).max);

        uint256 initialOwnerBalance = laToken.balanceOf(owner);
        uint256 initialContractBalance = laToken.balanceOf(address(escrow));

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit LAEscrow.AgreementActivated(user2);
        escrow.activateAgreement(user2);

        LAEscrow.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user2);
        assertEq(agreement.activationDate, block.timestamp);
        assertEq(laToken.balanceOf(owner), initialOwnerBalance - 200 ether);
        assertEq(
            laToken.balanceOf(address(escrow)),
            initialContractBalance + 200 ether
        );
    }

    function test_ActivateAgreementForUser_RevertsWhen_NoAgreementExists()
        public
    {
        vm.prank(treasury);
        vm.expectRevert(LAEscrow.InvalidAgreement.selector);
        escrow.activateAgreement(user1);
    }

    function test_ActivateAgreementForUser_RevertsWhen_AlreadyActivated()
        public
    {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(treasury);
        escrow.activateAgreement(user1);

        vm.prank(treasury);
        vm.expectRevert(LAEscrow.AgreementAlreadyActivated.selector);
        escrow.activateAgreement(user1);
    }

    function test_ActivateAgreementForUser_TransferFromCaller_NotUser()
        public
    {
        _createAgreementForUser(user3, 150 ether, 15 ether, 45, 9);

        uint256 initialUserBalance = laToken.balanceOf(user3);
        uint256 initialTreasuryBalance = laToken.balanceOf(treasury);

        vm.prank(treasury);
        escrow.activateAgreement(user3);

        // Confirm tokens were pulled from treasury and not from user3
        assertEq(laToken.balanceOf(user3), initialUserBalance);
        assertEq(
            laToken.balanceOf(treasury), initialTreasuryBalance - 150 ether
        );
    }

    function test_ActivateAgreement_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        uint256 initialBalance = laToken.balanceOf(user1);
        uint256 initialContractBalance = laToken.balanceOf(address(escrow));

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit LAEscrow.AgreementActivated(user1);
        escrow.activateAgreement();

        LAEscrow.EscrowAgreement memory agreement =
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
        vm.expectRevert(LAEscrow.InvalidAgreement.selector);
        escrow.activateAgreement();
    }

    function test_ActivateAgreement_RevertsWhen_AlreadyActivated() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user1);
        escrow.activateAgreement();

        vm.prank(user1);
        vm.expectRevert(LAEscrow.AgreementAlreadyActivated.selector);
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
        emit LAEscrow.RebateClaimed(user1, expectedClaim);
        escrow.claim();

        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        LAEscrow.EscrowAgreement memory agreement =
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
        escrow.claim();

        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        // Agreement should be deleted
        LAEscrow.EscrowAgreement memory agreement =
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
        escrow.claim();

        // Second claim after 20 days
        vm.warp(block.timestamp + 10 days);
        uint256 secondClaim = 4 * 10 ether; // 4 more rebates

        vm.prank(user1);
        escrow.claim();

        // Final claim after 31 days
        vm.warp(block.timestamp + 11 days);
        uint256 finalClaim = 4 * 10 ether; // Remaining 4 rebates

        vm.prank(user1);
        escrow.claim();

        // Agreement should be deleted
        LAEscrow.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);

        assertEq(
            laToken.balanceOf(user1),
            initialBalance + firstClaim + secondClaim + finalClaim
        );
    }

    function test_Claim_RevertsWhen_NoAgreementExists() public {
        vm.prank(user1);
        vm.expectRevert(LAEscrow.InvalidAgreement.selector);
        escrow.claim();
    }

    function test_Claim_RevertsWhen_AgreementNotActivated() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user1);
        vm.expectRevert(LAEscrow.InvalidAgreement.selector);
        escrow.claim();
    }

    function test_Claim_RevertsWhen_NoClaimableRebates() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Try to claim immediately after activation
        vm.prank(user1);
        vm.expectRevert(LAEscrow.NoClaimableRebates.selector);
        escrow.claim();
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
        escrow.claim();
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
        emit LAEscrow.Distributed(recipient, amount);
        escrow.distribute(recipient, amount);

        assertEq(laToken.balanceOf(recipient), amount);
    }

    function test_Distribute_RevertsWhen_NotTreasury() public {
        vm.prank(user1);
        vm.expectRevert(LAEscrow.OnlyTreasuryCanDistribute.selector);
        escrow.distribute(user1, 100 ether);
    }

    function test_Distribute_RevertsWhen_AmountIsZero() public {
        vm.prank(treasury);
        vm.expectRevert(LAEscrow.InvalidAmount.selector);
        escrow.distribute(user1, 0);
    }

    function test_Distribute_RevertsWhen_RecipientIsZeroAddress() public {
        vm.prank(treasury);
        vm.expectRevert(LAEscrow.InvalidRecipient.selector);
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
        LAEscrow.EscrowAgreement memory agreement =
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
        LAEscrow.EscrowAgreement memory agreement =
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
        escrow.claim();

        // Verify agreement still exists with some claims
        LAEscrow.EscrowAgreement memory agreement =
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
        vm.expectRevert(LAEscrow.InvalidAgreement.selector);
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
        LAEscrow.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 0);

        // Create new agreement for same user
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
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

        LAEscrow.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.paymentAmount, 100 ether);
        assertEq(agreement.rebateAmount, 10 ether);
        assertEq(agreement.durationDays, 30);
        assertEq(agreement.numRebates, 12);
        assertEq(agreement.numRebatesClaimed, 0);
        assertEq(agreement.activationDate, 0);
    }

    function test_GetEscrowAgreement_ReturnsEmptyForNonExistent() public view {
        LAEscrow.EscrowAgreement memory agreement =
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
        escrow.claim();
        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);
    }

    function test_Claim_WithOneDayDuration() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 1, 1);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        escrow.claim();

        // Agreement should be deleted
        LAEscrow.EscrowAgreement memory agreement =
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
        LAEscrow.NewEscrowAgreementParams memory params = LAEscrow
            .NewEscrowAgreementParams({
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
