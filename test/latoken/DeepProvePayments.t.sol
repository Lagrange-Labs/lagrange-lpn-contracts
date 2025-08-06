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
    address public feeCollector;
    address public owner;
    address public biller;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        feeCollector = makeAddr("feeCollector");
        biller = makeAddr("biller");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy TestERC20 token
        laToken = new TestERC20();

        // Deploy DeepProvePayments implementation
        implementation =
            new DeepProvePayments(address(laToken), treasury, feeCollector);

        // Prepare initializer data
        bytes memory initData = abi.encodeWithSelector(
            DeepProvePayments.initialize.selector, owner, biller
        );

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
        new DeepProvePayments(address(0), treasury, feeCollector);
    }

    function test_Constructor_RevertsWhen_TreasuryIsZero() public {
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        new DeepProvePayments(address(laToken), address(0), feeCollector);
    }

    function test_Constructor_RevertsWhen_FeeCollectorIsZero() public {
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        new DeepProvePayments(address(laToken), treasury, address(0));
    }

    function test_Initialize_Success() public view {
        assertEq(address(escrow.LA_TOKEN()), address(laToken));
        assertEq(escrow.TREASURY(), treasury);
        assertEq(escrow.FEE_COLLECTOR(), feeCollector);
        assertEq(escrow.owner(), owner);
        assertEq(escrow.getBiller(), biller);
    }

    function test_Initialize_RevertsWhen_CalledAgain() public {
        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        escrow.initialize(owner, biller);
    }

    function test_Initialize_RevertsWhen_CalledOnImplementation() public {
        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(owner, biller);
    }

    function test_Initialize_RevertsWhen_BillerIsZero() public {
        DeepProvePayments newImpl =
            new DeepProvePayments(address(laToken), treasury, feeCollector);

        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        new TransparentUpgradeableProxy(
            address(newImpl),
            owner,
            abi.encodeWithSelector(
                DeepProvePayments.initialize.selector, owner, address(0)
            )
        );
    }

    // ------------------------------------------------------------
    //                    AGREEMENT CREATION TESTS                |
    // ------------------------------------------------------------

    function test_CreateAgreement_Success() public {
        uint256 depositAmount = 100 ether;
        uint256 rebateAmount = 10 ether;
        uint16 durationDays = 30;
        uint8 numRebates = 12;

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DeepProvePayments.NewAgreement(
            user1,
            DeepProvePayments.EscrowAgreement({
                depositAmountGwei: 100000000000, // 100 ether in gwei (100 * 1e9)
                rebateAmountGwei: 10000000000, // 10 ether in gwei (10 * 1e9)
                balance: 0,
                durationDays: 30,
                numRebates: 12,
                numRebatesClaimed: 0,
                activationDate: 0
            })
        );
        escrow.createAgreement(
            user1, depositAmount, rebateAmount, durationDays, numRebates
        );

        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // 100 ether in gwei
        assertEq(agreement.rebateAmountGwei, 10000000000); // 10 ether in gwei
        assertEq(agreement.durationDays, 30);
        assertEq(agreement.numRebates, 12);
        assertEq(agreement.numRebatesClaimed, 0);
        assertEq(agreement.activationDate, 0);
    }

    function test_CreateAgreement_RevertsWhen_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, user1
            )
        );
        escrow.createAgreement(user1, 100 ether, 10 ether, 30, 12);
    }

    function test_CreateAgreement_RevertsWhen_UserIsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        escrow.createAgreement(address(0), 100 ether, 10 ether, 30, 12);
    }

    function test_CreateAgreement_RevertsWhen_DepositAmountIsZero() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.createAgreement(user1, 0, 10 ether, 30, 12);
    }

    function test_CreateAgreement_RevertsWhen_RebateAmountIsZero() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.createAgreement(user1, 100 ether, 0, 30, 12);
    }

    function test_CreateAgreement_RevertsWhen_DurationDaysIsZero() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidConfig.selector);
        escrow.createAgreement(user1, 100 ether, 10 ether, 0, 12);
    }

    function test_CreateAgreement_RevertsWhen_NumRebatesIsZero() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidConfig.selector);
        escrow.createAgreement(user1, 100 ether, 10 ether, 30, 0);
    }

    function test_CreateAgreement_RevertsWhen_AgreementAlreadyExists() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.AgreementAlreadyExists.selector);
        escrow.createAgreement(user1, 100 ether, 10 ether, 30, 12);
    }

    function test_CreateAgreement_RevertsWhen_DepositAmountNotDivisibleByGwei()
        public
    {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.createAgreement(user1, 100 ether + 1, 10 ether, 30, 12); // Add 1 wei to make it not divisible by 1e9
    }

    function test_CreateAgreement_RevertsWhen_RebateAmountNotDivisibleByGwei()
        public
    {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.createAgreement(user1, 100 ether, 10 ether + 1, 30, 12); // Add 1 wei to make it not divisible by 1e9
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
        assertEq(agreement.balance, 100 ether);
        assertEq(escrow.getBalance(user1), 100 ether);
        assertEq(escrow.getEscrowBalance(user1), 100 ether);
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

        // Agreement should still exist with all rebates claimed
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // Still exists
        assertEq(agreement.numRebatesClaimed, 12); // All rebates claimed
        assertFalse(escrow.hasClaimableRebates(user1));
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

        // Agreement should still exist with all rebates claimed
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // Still exists
        assertEq(agreement.numRebatesClaimed, 12); // All rebates claimed

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

        // Drain contract balance by charging user
        vm.prank(biller);
        escrow.charge(user1, 99 ether);

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
    //                      CHARGE TESTS                          |
    // ------------------------------------------------------------

    function test_GetBiller_Success() public view {
        assertEq(escrow.getBiller(), biller);
    }

    function test_SetBiller_Success() public {
        address newBiller = makeAddr("newBiller");

        vm.prank(owner);
        escrow.setBiller(newBiller);

        assertEq(escrow.getBiller(), newBiller);
    }

    function test_SetBiller_RevertsWhen_NotOwner() public {
        address newBiller = makeAddr("newBiller");

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, user1
            )
        );
        escrow.setBiller(newBiller);
    }

    function test_SetBiller_RevertsWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        escrow.setBiller(address(0));
    }

    // ------------------------------------------------------------
    //                      CHARGE TESTS                          |
    // ------------------------------------------------------------

    function test_Charge_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        uint88 chargeAmount = 20 ether;
        uint256 initialFeeCollectorBalance = laToken.balanceOf(feeCollector);
        uint256 initialContractBalance = laToken.balanceOf(address(escrow));

        vm.prank(biller);
        vm.expectEmit(true, true, true, true);
        emit DeepProvePayments.Charged(user1, chargeAmount);
        escrow.charge(user1, chargeAmount);

        assertEq(escrow.getBalance(user1), 100 ether - chargeAmount);
        assertEq(
            laToken.balanceOf(feeCollector),
            initialFeeCollectorBalance + chargeAmount
        );
        assertEq(
            laToken.balanceOf(address(escrow)),
            initialContractBalance - chargeAmount
        );
    }

    function test_Charge_RevertsWhen_NotBiller() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(user1);
        vm.expectRevert(DeepProvePayments.OnlyBillerCanCharge.selector);
        escrow.charge(user1, 20 ether);
    }

    function test_Charge_RevertsWhen_AmountIsZero() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(biller);
        vm.expectRevert(DeepProvePayments.InvalidAmount.selector);
        escrow.charge(user1, 0);
    }

    function test_Charge_RevertsWhen_InsufficientBalance() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        vm.prank(biller);
        vm.expectRevert(DeepProvePayments.InsufficientBalance.selector);
        escrow.charge(user1, 150 ether);
    }

    function test_Charge_MultipleCharges_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        uint256 initialFeeCollectorBalance = laToken.balanceOf(feeCollector);

        // First charge
        vm.prank(biller);
        escrow.charge(user1, 30 ether);

        assertEq(escrow.getBalance(user1), 70 ether);
        assertEq(
            laToken.balanceOf(feeCollector),
            initialFeeCollectorBalance + 30 ether
        );

        // Second charge
        vm.prank(biller);
        escrow.charge(user1, 20 ether);

        assertEq(escrow.getBalance(user1), 50 ether);
        assertEq(
            laToken.balanceOf(feeCollector),
            initialFeeCollectorBalance + 50 ether
        );
    }

    function test_Charge_RevertsWhen_ContractHasInsufficientTokens() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Somehow drain contract tokens (e.g., through rebate claims)
        vm.warp(block.timestamp + 15 days);
        vm.prank(user1);
        escrow.claimRebates(); // Claims 60 ether, leaves 40 ether

        // Try to charge more than what's left in contract
        vm.prank(biller);
        vm.expectRevert();
        escrow.charge(user1, 50 ether);
    }

    // ------------------------------------------------------------
    //                    CANCEL AGREEMENT TESTS                  |
    // ------------------------------------------------------------

    function test_CancelAgreement_WhenNotActivated_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        // Verify agreement exists
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // 100 ether in gwei

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 0);
    }

    function test_CancelAgreement_WhenActivated_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Verify agreement exists and is activated
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // 100 ether in gwei
        assertGt(agreement.activationDate, 0);

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 0);
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
        assertEq(agreement.depositAmountGwei, 100000000000); // 100 ether in gwei
        assertGt(agreement.numRebatesClaimed, 0);

        // Cancel agreement
        vm.prank(owner);
        escrow.cancelAgreement(user1);

        // Verify agreement is deleted
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 0);
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
        assertEq(agreement.depositAmountGwei, 0);

        // Create new agreement for same user
        vm.prank(owner);
        escrow.createAgreement(user1, 150 ether, 15 ether, 45, 18);

        // Verify new agreement exists
        agreement = escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 150000000000); // 150 ether in gwei
    }

    // ------------------------------------------------------------
    //                        VIEW TESTS                          |
    // ------------------------------------------------------------

    function test_GetEscrowAgreement_Success() public {
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // 100 ether in gwei
        assertEq(agreement.rebateAmountGwei, 10000000000); // 10 ether in gwei
        assertEq(agreement.durationDays, 30);
        assertEq(agreement.numRebates, 12);
        assertEq(agreement.numRebatesClaimed, 0);
        assertEq(agreement.activationDate, 0);
    }

    function test_GetEscrowAgreement_ReturnsEmptyForNonExistent() public view {
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 0);
    }

    function test_GetBalance_Success() public {
        // Create an agreement for user1
        _createAgreementForUser(user1, 100 ether, 10 ether, 30, 12);

        // Check balance before activation
        uint256 balance = escrow.getBalance(user1);
        assertEq(balance, 0);
        assertEq(escrow.getEscrowBalance(user1), 0);
        assertEq(escrow.getALaCarteBalance(user1), 0);

        // Activate agreement
        vm.startPrank(user1);
        laToken.approve(address(escrow), 100 ether);
        escrow.activateAgreement();
        vm.stopPrank();

        // Check balance after activation
        balance = escrow.getBalance(user1);
        assertEq(balance, 100 ether);
        assertEq(escrow.getEscrowBalance(user1), 100 ether);
        assertEq(escrow.getALaCarteBalance(user1), 0);

        // Charge some amount and check balance
        vm.prank(biller);
        escrow.charge(user1, 30 ether);

        balance = escrow.getBalance(user1);
        assertEq(balance, 70 ether);
        assertEq(escrow.getEscrowBalance(user1), 70 ether);
        assertEq(escrow.getALaCarteBalance(user1), 0);
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

        // Remove most of the contract balance by charging user
        vm.prank(biller);
        escrow.charge(user1, 99 ether);

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

        // Agreement should still exist with all rebates claimed
        DeepProvePayments.EscrowAgreement memory agreement =
            escrow.getEscrowAgreement(user1);
        assertEq(agreement.depositAmountGwei, 100000000000); // Still exists
        assertEq(agreement.numRebatesClaimed, 1); // All rebates claimed
    }

    // ------------------------------------------------------------
    //                      USER STRUCT TESTS                     |
    // ------------------------------------------------------------

    function test_GetALaCarteBalance_Success() public view {
        assertEq(escrow.getALaCarteBalance(user1), 0);
    }

    function test_GetEscrowBalance_Success() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        assertEq(escrow.getEscrowBalance(user1), 100 ether);
        assertEq(escrow.getALaCarteBalance(user1), 0);
        assertEq(escrow.getBalance(user1), 100 ether);
    }

    function test_Charge_WithOnlyALaCarte_RevertsWhen_NoBalance() public {
        vm.prank(biller);
        vm.expectRevert(DeepProvePayments.InsufficientBalance.selector);
        escrow.charge(user1, 20 ether);
    }

    function test_GetBalance_ReturnsTotal() public {
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Without a la carte balance, total balance equals escrow balance
        assertEq(escrow.getBalance(user1), 100 ether);
        assertEq(escrow.getEscrowBalance(user1), 100 ether);
        assertEq(escrow.getALaCarteBalance(user1), 0 ether);
    }

    function test_IsWhitelisted_Success() public {
        // Initially not whitelisted
        assertEq(escrow.isWhitelisted(user1), false);

        // Create and activate agreement
        _createAndActivateAgreement(user1, 100 ether, 10 ether, 30, 12);

        // Should be whitelisted after activation
        assertEq(escrow.isWhitelisted(user1), true);
    }

    function test_SetWhitelisted_Success() public {
        // Initially not whitelisted
        assertEq(escrow.isWhitelisted(user1), false);

        // Set to whitelisted
        vm.prank(owner);
        escrow.setWhitelisted(user1, true);
        assertEq(escrow.isWhitelisted(user1), true);

        // Set back to not whitelisted
        vm.prank(owner);
        escrow.setWhitelisted(user1, false);
        assertEq(escrow.isWhitelisted(user1), false);
    }

    function test_SetWhitelisted_RevertsWhen_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, user1
            )
        );
        escrow.setWhitelisted(user1, true);
    }

    function test_SetWhitelisted_RevertsWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DeepProvePayments.ZeroAddress.selector);
        escrow.setWhitelisted(address(0), true);
    }

    // ------------------------------------------------------------
    //                    TEST HELPER FUNCTIONS                   |
    // ------------------------------------------------------------

    function _createAgreementForUser(
        address user,
        uint256 depositAmount,
        uint256 rebateAmount,
        uint16 durationDays,
        uint8 numRebates
    ) internal {
        vm.prank(owner);
        escrow.createAgreement(
            user, depositAmount, rebateAmount, durationDays, numRebates
        );
    }

    function _createAndActivateAgreement(
        address user,
        uint256 depositAmount,
        uint256 rebateAmount,
        uint16 durationDays,
        uint8 numRebates
    ) internal {
        _createAgreementForUser(
            user, depositAmount, rebateAmount, durationDays, numRebates
        );
        vm.prank(user);
        escrow.activateAgreement();
    }
}
