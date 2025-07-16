// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TestERC20} from "../../src/mocks/TestERC20.sol";
import {LAPublicStaker} from "../../src/latoken/LAPublicStaker.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {Initializable} from
    "@openzeppelin-contracts-5.2.0/proxy/utils/Initializable.sol";
import {console} from "forge-std/console.sol";

contract LAPublicStakerTest is Test {
    LAPublicStaker public staker;
    TestERC20 public laToken;
    address public treasury;
    address public owner;
    address public user1;
    address public user2;
    address public recipient;

    function setUp() public {
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        recipient = makeAddr("recipient");

        // Deploy TestERC20 token
        laToken = new TestERC20();

        // Deploy LAPublicStaker implementation
        LAPublicStaker implementation =
            new LAPublicStaker(address(laToken), treasury);

        // Prepare initializer data
        LAPublicStaker.Config memory config = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 30,
            stakeCap: 100_000 ether
        });
        bytes memory initData = abi.encodeWithSelector(
            LAPublicStaker.initialize.selector, owner, config
        );

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner, // admin
            initData
        );

        // Interact with LAPublicStaker via proxy
        staker = LAPublicStaker(address(proxy));

        // Mint tokens to users
        laToken.mint(user1, 1000 ether);
        laToken.mint(user2, 1000 ether);
        laToken.mint(treasury, 10000 ether);

        vm.prank(user1);
        laToken.approve(address(staker), type(uint256).max);
        vm.prank(user2);
        laToken.approve(address(staker), type(uint256).max);
        vm.prank(treasury);
        laToken.approve(address(staker), type(uint256).max);
    }

    function test_Version_Constant() public view {
        assertEq(staker.VERSION(), "1.0.0");
    }

    function test_Constructor_RevertsWhen_LaTokenIsZero() public {
        vm.expectRevert(LAPublicStaker.ZeroAddress.selector);
        new LAPublicStaker(address(0), treasury);
    }

    function test_Constructor_RevertsWhen_TreasuryIsZero() public {
        vm.expectRevert(LAPublicStaker.ZeroAddress.selector);
        new LAPublicStaker(address(laToken), address(0));
    }

    function test_Initialize_Success() public view {
        assertEq(address(staker.LA_TOKEN()), address(laToken));
        assertEq(staker.TREASURY(), treasury);
        assertEq(staker.owner(), owner);
    }

    function test_Initialize_RevertsWhen_CalledAgain() public {
        LAPublicStaker.Config memory config = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 30,
            stakeCap: 10_000 ether
        });
        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        staker.initialize(owner, config);
    }

    function test_Initialize_RevertsWhen_CalledOnImplementation() public {
        LAPublicStaker implementation =
            new LAPublicStaker(address(laToken), treasury);
        LAPublicStaker.Config memory config = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 30,
            stakeCap: 10_000 ether
        });
        vm.prank(owner);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(owner, config);
    }

    function test_Stake_CalculatesRewardsOwed_Success() public {
        uint256 stakeAmount1 = 100 ether;
        uint256 expectedRewards1 = (stakeAmount1 * 100 * 30) / 365000;
        vm.prank(user1);
        staker.stake(stakeAmount1);
        assertEq(
            staker.getStakePositions(user1)[0].rewardsOwed, expectedRewards1
        );

        // Change APY to 150 PPT (15% APY) and test again
        LAPublicStaker.Config memory newConfig = LAPublicStaker.Config({
            apyPPT: 150,
            lockupPeriodDays: 365,
            stakeCap: 10_000 ether
        });
        vm.prank(owner);
        staker.setConfig(newConfig);

        uint96 stakeAmount2 = 200 ether;
        uint256 expectedRewards2 = 30 ether;
        vm.prank(user1);
        staker.stake(stakeAmount2);
        assertEq(
            staker.getStakePositions(user1)[1].rewardsOwed, expectedRewards2
        );
    }

    function test_Stake_CalculatesMatureDate_Success() public {
        uint256 stakeAmount = 100 ether;
        uint256 expectedMatureDate = block.timestamp + 30 days;
        vm.prank(user1);
        staker.stake(stakeAmount);
        assertEq(
            staker.getStakePositions(user1)[0].matureDate, expectedMatureDate
        );

        // Change lockup period to 60 days and test again
        LAPublicStaker.Config memory newConfig = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 60,
            stakeCap: 10_000 ether
        });
        vm.prank(owner);
        staker.setConfig(newConfig);

        vm.prank(user1);
        staker.stake(stakeAmount);
        expectedMatureDate = block.timestamp + 60 days;
        assertEq(
            staker.getStakePositions(user1)[1].matureDate, expectedMatureDate
        );
    }

    function test_Stake_CalculatesStakeCap_Success() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(user1);
        staker.stake(stakeAmount);
        assertEq(staker.getTotalStaked(), stakeAmount);

        uint256 stakeAmount2 = 200 ether;
        vm.prank(user2);
        staker.stake(stakeAmount2);
        assertEq(staker.getTotalStaked(), stakeAmount + stakeAmount2);
    }

    function test_Stake_WithMultipleUsers_Success() public {
        uint96 stakeAmount = 100 ether;

        // User1 stakes
        vm.prank(user1);
        staker.stake(stakeAmount);

        // User2 stakes
        vm.prank(user2);
        staker.stake(stakeAmount);

        // Verify both users have stakes
        LAPublicStaker.StakePosition[] memory positions1 =
            staker.getStakePositions(user1);
        LAPublicStaker.StakePosition[] memory positions2 =
            staker.getStakePositions(user2);

        assertEq(positions1.length, 1);
        assertEq(positions2.length, 1);
        assertEq(positions1[0].amountStaked, stakeAmount);
        assertEq(positions2[0].amountStaked, stakeAmount);
    }

    function test_Stake_RevertsWhen_AmountIsZero() public {
        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.InvalidAmount.selector);
        staker.stake(0);
    }

    function test_Stake_RevertsWhen_InsufficientAllowance() public {
        vm.startPrank(user1);
        laToken.approve(address(staker), 100 ether);
        vm.expectRevert();
        staker.stake(101 ether);
        vm.stopPrank();
    }

    function test_Stake_RevertsWhen_InsufficientBalance() public {
        uint256 balance = laToken.balanceOf(user1);
        vm.expectRevert();
        vm.prank(user1);
        staker.stake(balance + 1);
    }

    function test_Stake_RevertsWhen_StakeCapExceeded() public {
        uint256 stakeCap = staker.getConfig().stakeCap;
        laToken.mint(user1, stakeCap + 1);
        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.StakeCapExceeded.selector);
        staker.stake(stakeCap + 1);
    }

    function test_Stake_RevertsWhen_RewardsWouldBeZero() public {
        uint256 smallStake = 100; // This will result in 100 * 100 * 30 / 365000 = 0 rewards

        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.InvalidAmount.selector);
        staker.stake(smallStake);
    }

    function test_Claim_Success() public {
        uint96 stakeAmount1 = 100 ether;
        uint96 stakeAmount2 = 200 ether;
        uint96 stakeAmount3 = 300 ether;

        // Create 3 stake positions at different times, with different lockup periods
        vm.prank(user1);
        staker.stake(stakeAmount1);

        vm.warp(block.timestamp + 1 days);
        _setLockupPeriodDays(100); // stake #2 won't mature in time
        vm.prank(user1);
        staker.stake(stakeAmount2);

        vm.warp(block.timestamp + 10 days);
        _setLockupPeriodDays(15); // stake #3 will mature in time
        vm.prank(user1);
        staker.stake(stakeAmount3);

        // Fast forward past lockup period for stakes #1 and #3
        vm.warp(block.timestamp + 20 days);

        // Get initial balances
        uint256 initialBalance = laToken.balanceOf(user1);
        uint256 expectedClaim = (
            stakeAmount1 + (stakeAmount1 * 100 * 30) / 365000
        ) + (stakeAmount3 + (stakeAmount3 * 100 * 15) / 365000);

        // Test getters
        assertEq(staker.hasClaimableRewards(user1), true);
        assertEq(
            staker.getTotalStaked(user1),
            stakeAmount1 + stakeAmount2 + stakeAmount3
        );
        assertEq(
            staker.getTotalPendingRewards(user1),
            (stakeAmount1 * 100 * 30) / 365000
                + (stakeAmount2 * 100 * 100) / 365000
                + (stakeAmount3 * 100 * 15) / 365000 // stake #3 is mature, so it has interest
        );

        // Claim rewards
        vm.prank(user1);
        staker.claim();

        // Check final balance
        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        // Check that only 1 stake position remains (the second one wasn't eligible)
        LAPublicStaker.StakePosition[] memory positions =
            staker.getStakePositions(user1);
        assertEq(positions.length, 1);
        assertEq(positions[0].amountStaked, stakeAmount2);

        // User has no claimable rewards after claiming
        assertFalse(staker.hasClaimableRewards(user1));

        // Fast forward again to make stake #2 mature
        vm.warp(block.timestamp + 100 days);
        assertTrue(staker.hasClaimableRewards(user1));

        expectedClaim = stakeAmount2 + (stakeAmount2 * 100 * 100) / 365000;

        assertEq(staker.getCurrentClaimableAmount(user1), expectedClaim);

        // Claim stake #2
        initialBalance = laToken.balanceOf(user1);
        vm.prank(user1);
        staker.claim();
        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        assertEq(staker.getStakePositions(user1).length, 0);
    }

    function test_Claim_MultipleStakesSameMatureDate_Success() public {
        // Create multiple stakes with same mature date
        uint96 stakeAmount = 100 ether;

        vm.startPrank(user1);
        staker.stake(stakeAmount);
        staker.stake(stakeAmount);
        staker.stake(stakeAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        uint256 initialBalance = laToken.balanceOf(user1);
        uint256 expectedClaim =
            3 * (stakeAmount + (stakeAmount * 100 * 30) / 365000);

        assertEq(staker.getNextRewardAmount(user1), 0);
        assertEq(staker.getCurrentClaimableAmount(user1), expectedClaim);

        // Should claim all three stakes
        vm.prank(user1);
        staker.claim();
        assertEq(laToken.balanceOf(user1), initialBalance + expectedClaim);

        // Should have no stakes remaining
        LAPublicStaker.StakePosition[] memory positions =
            staker.getStakePositions(user1);
        assertEq(positions.length, 0);
    }

    function test_Claim_RevertsWhen_UserHasAlreadyClaimed() public {
        uint256 stakeAmount = 100 ether;

        // User stakes tokens
        vm.prank(user1);
        staker.stake(stakeAmount);

        // Fast forward past lockup period
        vm.warp(block.timestamp + 31 days);

        // First claim should succeed
        vm.prank(user1);
        staker.claim();

        // Second claim should revert since all stakes have been claimed
        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.NoClaimableStake.selector);
        staker.claim();
    }

    function test_Claim_RevertsWhen_UserHasNoStake() public {
        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.NoClaimableStake.selector);
        staker.claim();
    }

    function test_Claim_RevertsWhen_CalledBeforeLockupPeriodEnds() public {
        uint96 stakeAmount = 100 ether;

        vm.prank(user1);
        staker.stake(stakeAmount);

        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.NoClaimableStake.selector);
        staker.claim();
    }

    function test_Claim_RevertsWhen_TreasuryTransferFails() public {
        uint96 stakeAmount = 100 ether;
        vm.prank(user1);
        staker.stake(stakeAmount);

        vm.warp(block.timestamp + 31 days);

        // Drain treasury balance
        uint256 treasuryBalance = laToken.balanceOf(treasury);
        vm.prank(treasury);
        laToken.transfer(address(0xdeadbeef), treasuryBalance);

        vm.prank(user1);
        vm.expectRevert();
        staker.claim();
    }

    function test_Distribute_Success() public {
        // Mint tokens directly to the staker contract
        uint256 amount = 100 ether;
        laToken.mint(address(staker), amount);

        vm.prank(treasury);
        staker.distribute(recipient, amount);

        assertEq(laToken.balanceOf(recipient), amount);
    }

    function test_Distribute_RevertsWhen_NotTreasury() public {
        vm.prank(user1);
        vm.expectRevert(LAPublicStaker.OnlyTreasuryCanDistribute.selector);
        staker.distribute(user1, 100 ether);
    }

    function test_Distribute_RevertsWhen_AmountIsZero() public {
        vm.prank(treasury);
        vm.expectRevert(LAPublicStaker.InvalidAmount.selector);
        staker.distribute(treasury, 0);
    }

    function test_Distribute_RevertsWhen_RecipientIsZeroAddress() public {
        vm.prank(treasury);
        vm.expectRevert(LAPublicStaker.InvalidRecipient.selector);
        staker.distribute(address(0), 100 ether);
    }

    function test_Distribute_RevertsWhen_TransferFails() public {
        // Try to distribute more than contract has
        vm.startPrank(treasury);
        uint256 balance = laToken.balanceOf(address(staker));
        vm.expectRevert();
        staker.distribute(makeAddr("recipient"), balance + 1);
        vm.stopPrank();
    }

    function test_GetStakePositions_Success() public {
        uint96 stakeAmount = 100 ether;

        vm.prank(user1);
        staker.stake(stakeAmount);

        LAPublicStaker.StakePosition[] memory positions =
            staker.getStakePositions(user1);
        assertEq(positions.length, 1);
        assertEq(positions[0].amountStaked, stakeAmount);
    }

    function test_HasClaimableRewards_Success() public {
        uint96 stakeAmount = 100 ether;

        vm.prank(user1);
        staker.stake(stakeAmount);

        assertFalse(staker.hasClaimableRewards(user1));

        vm.warp(block.timestamp + 31 days);
        assertTrue(staker.hasClaimableRewards(user1));
    }

    function test_GetCurrentClaimableAmount_Success() public {
        uint96 stakeAmount = 100 ether;
        uint256 expectedInterest = (stakeAmount * 100 * 30) / 365000;

        vm.prank(user1);
        staker.stake(stakeAmount);

        assertEq(staker.getCurrentClaimableAmount(user1), 0);

        vm.warp(block.timestamp + 31 days);
        assertEq(
            staker.getCurrentClaimableAmount(user1),
            stakeAmount + expectedInterest
        );
    }

    function test_getNextRewardDate_Success() public {
        uint96 stakeAmount = 100 ether;

        vm.prank(user1);
        staker.stake(stakeAmount);

        uint256 expectedPayoutDate1 = block.timestamp + 30 days;

        assertEq(staker.getNextRewardDate(user1), expectedPayoutDate1);

        // Change lockup period to 15 days and stake again
        LAPublicStaker.Config memory shorterConfig = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 15,
            stakeCap: 100_000 ether
        });
        vm.prank(owner);
        staker.setConfig(shorterConfig);

        uint256 expectedMatureDate2 = block.timestamp + 15 days;
        vm.prank(user1);
        staker.stake(stakeAmount);

        // Verify the next payout data is now sooner
        assertEq(staker.getNextRewardDate(user1), expectedMatureDate2); // payout date stays the same

        vm.warp(block.timestamp + 60 days);
        assertEq(staker.getNextRewardDate(user1), 0); // all rewards have matured
    }

    function test_getNextRewardAmount_Success() public {
        uint96 stakeAmount1 = 100 ether;

        vm.prank(user1);
        staker.stake(stakeAmount1);

        _setLockupPeriodDays(1); // stake 2 will mature first

        uint96 stakeAmount2 = 200 ether;
        uint256 expectedRewards2 = (stakeAmount2 * 100 * 1) / 365000;

        vm.prank(user1);
        staker.stake(stakeAmount2);

        assertEq(
            staker.getNextRewardAmount(user1), stakeAmount2 + expectedRewards2
        );
    }

    function test_GetTotalStaked_Success() public {
        uint96 stakeAmount1 = 100 ether;
        uint96 stakeAmount2 = 200 ether;

        vm.prank(user1);
        staker.stake(stakeAmount1);
        vm.prank(user1);
        staker.stake(stakeAmount2);

        assertEq(staker.getTotalStaked(user1), stakeAmount1 + stakeAmount2);
    }

    function test_getTotalPendingRewards_Success() public {
        uint96 stakeAmount1 = 100 ether;
        uint96 stakeAmount2 = 200 ether;
        uint256 expectedRewards1 = (stakeAmount1 * 100 * 30) / 365000;
        uint256 expectedRewards2 = (stakeAmount2 * 100 * 30) / 365000;

        vm.prank(user1);
        staker.stake(stakeAmount1);
        vm.prank(user1);
        staker.stake(stakeAmount2);

        assertEq(
            staker.getTotalPendingRewards(user1),
            expectedRewards1 + expectedRewards2
        );
    }

    function test_GetTotalPendingPayout_Success() public {
        uint96 stakeAmount1 = 100 ether;
        uint96 stakeAmount2 = 200 ether;
        uint256 expectedRewards1 = (stakeAmount1 * 100 * 30) / 365000;
        uint256 expectedRewards2 = (stakeAmount2 * 100 * 30) / 365000;

        vm.prank(user1);
        staker.stake(stakeAmount1);
        vm.prank(user1);
        staker.stake(stakeAmount2);

        assertEq(
            staker.getTotalPendingPayout(user1),
            stakeAmount1 + stakeAmount2 + expectedRewards1 + expectedRewards2
        );
    }

    function test_SetConfig_Success() public {
        LAPublicStaker.Config memory newConfig = LAPublicStaker.Config({
            apyPPT: 200, // 20% APY
            lockupPeriodDays: 60,
            stakeCap: 20_000 ether
        });

        vm.prank(owner);
        staker.setConfig(newConfig);

        assertEq(
            keccak256(abi.encode(newConfig)),
            keccak256(abi.encode(staker.getConfig()))
        );
    }

    function test_SetConfig_NotOwner() public {
        LAPublicStaker.Config memory newConfig = LAPublicStaker.Config({
            apyPPT: 200,
            lockupPeriodDays: 60,
            stakeCap: 10_000 ether
        });

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, user1
            )
        );
        staker.setConfig(newConfig);
    }

    function test_SetConfig_RevertsWhen_ConfigIsInvalid() public {
        LAPublicStaker.Config memory invalidConfig = LAPublicStaker.Config({
            apyPPT: 0,
            lockupPeriodDays: 30,
            stakeCap: 10_000 ether
        });

        vm.prank(owner);
        vm.expectRevert(LAPublicStaker.InvalidConfig.selector);
        staker.setConfig(invalidConfig);

        LAPublicStaker.Config memory invalidConfig2 = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 0,
            stakeCap: 10_000 ether
        });

        vm.prank(owner);
        vm.expectRevert(LAPublicStaker.InvalidConfig.selector);
        staker.setConfig(invalidConfig2);

        LAPublicStaker.Config memory invalidConfig3 = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 0,
            stakeCap: 0
        });

        vm.prank(owner);
        vm.expectRevert(LAPublicStaker.InvalidConfig.selector);
        staker.setConfig(invalidConfig3);
    }

    function test_ViewFunctions_WithZeroAddress() public view {
        assertEq(staker.getStakePositions(address(0)).length, 0);
        assertFalse(staker.hasClaimableRewards(address(0)));
        assertEq(staker.getCurrentClaimableAmount(address(0)), 0);
        assertEq(staker.getNextRewardDate(address(0)), 0);
        assertEq(staker.getNextRewardAmount(address(0)), 0);
        assertEq(staker.getTotalStaked(address(0)), 0);
        assertEq(staker.getTotalPendingRewards(address(0)), 0);
        assertEq(staker.getTotalPendingPayout(address(0)), 0);
    }

    function test_ViewFunctions_WithNoStakes() public view {
        assertEq(staker.getStakePositions(user1).length, 0);
        assertFalse(staker.hasClaimableRewards(user1));
        assertEq(staker.getCurrentClaimableAmount(user1), 0);
        assertEq(staker.getNextRewardDate(user1), 0);
        assertEq(staker.getNextRewardAmount(user1), 0);
        assertEq(staker.getTotalStaked(user1), 0);
        assertEq(staker.getTotalPendingRewards(user1), 0);
        assertEq(staker.getTotalPendingPayout(user1), 0);
    }

    function test_EventEmissions() public {
        // Test ConfigSet event
        LAPublicStaker.Config memory newConfig = LAPublicStaker.Config({
            apyPPT: 100,
            lockupPeriodDays: 30,
            stakeCap: 10_000 ether
        });

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit LAPublicStaker.ConfigSet(newConfig);
        staker.setConfig(newConfig);

        // Test Staked event
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit LAPublicStaker.Staked(user1, 100 ether);
        staker.stake(100 ether);

        // Test Claimed event
        vm.warp(block.timestamp + 31 days);
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit LAPublicStaker.Claimed(
            user1, uint256(100 ether) + uint256(100 ether * 100 * 30) / 365000
        );
        staker.claim();

        // Test Distributed event
        laToken.mint(address(staker), 50 ether);
        vm.prank(treasury);
        vm.expectEmit(true, true, true, true);
        emit LAPublicStaker.Distributed(recipient, 50 ether);
        staker.distribute(recipient, 50 ether);
    }

    // TEST HELPER FUNCTIONS

    function _setLockupPeriodDays(uint16 newLockupPeriodDays) internal {
        LAPublicStaker.Config memory config = staker.getConfig();
        config.lockupPeriodDays = newLockupPeriodDays;
        vm.prank(owner);
        staker.setConfig(config);
    }
}
