# LAPublicStaker Contract

## Overview

The `LAPublicStaker` contract is a flexible staking mechanism for LA tokens that allows users to stake their tokens and earn rewards based on configurable APY and lockup periods. The contract is designed to be highly configurable, allowing the owner to adjust yield rates and lockup periods as needed.

## Requirements

### Core Functionality
- **Public Staking**: Anyone can stake LA tokens without restrictions
- **Multiple Stakes**: Users can stake multiple times, creating separate positions
- **Configurable Parameters**: Owner can modify APY, lockup period, and stake cap at any time
- **Manual Distribution**: Owner can manually distribute staked funds
- **Stake and Claim Cycle**: Users stake tokens and claim rewards after lockup period

### Key Features
- **Flexible Configuration**: APY, lockup period, and stake cap can be changed by owner
- **Position Tracking**: Each stake creates a separate position with its own maturity date
- **Batch Claiming**: Users can claim all matured positions in a single transaction
- **Treasury Integration**: Contract can pull additional funds from treasury if needed for payouts

## Lifecycle

### 1. Staking Process

**Function**: `stake(uint256 amount)`

1. User approves LA tokens to the staking contract
2. User calls `stake()` with desired amount
3. Contract validates:
   - Amount > 0
   - Total staked + new amount ≤ stake cap
4. Contract calculates rewards based on current APY and lockup period
5. New position is created with:
   - Staked amount
   - Calculated rewards
   - Maturity date (current time + lockup period)
6. LA tokens are transferred from user to contract
7. Event `Staked` is emitted

**Reward Calculation**:
```
rewards = (amount * apyPPT * lockupPeriodDays) / 365000
```

The 36500 comes from 356 days per year * 1000 from the APY "parts per thousand"

### 2. Claiming Process

**Function**: `claim()`

1. User calls `claim()` to collect matured positions
2. Contract iterates through user's positions from offset
3. For each matured position (matureDate ≤ current time):
   - Adds staked amount + rewards to total claimable
   - Deletes the position from storage
   - Increments offset counter
4. If no claimable positions exist, reverts with `NoClaimableStake`
5. If contract balance is insufficient, pulls additional funds from treasury
6. Transfers total claimable amount to user
7. Event `Claimed` is emitted

### 3. Configuration Management

**Function**: `setConfig(Config memory config)`

- Only callable by owner
- Updates APY, lockup period, and stake cap
- Affects only new stakes (existing positions retain original terms)
- Emits `ConfigSet` event

## Distribution Function

**Function**: `distribute(address to, uint256 amount)`

The `distribute` function provides a manual distribution mechanism for the owner to send LA tokens to specific recipients. This is currently used as a direct path for distributing funds to Lagrange provers, though the automated integration is not yet implemented.

### Usage
- Only callable by the treasury address
- Transfers specified amount of LA tokens to recipient
- Emits `Distributed` event
- Validates recipient is not zero address and amount > 0

## View Functions

### User Information
- `getStakePositions(address user)`: Returns all active positions for a user
- `getTotalStaked(address user)`: Returns total amount staked by user
- `getTotalPendingRewards(address user)`: Returns total rewards owed to user
- `getTotalPendingPayout(address user)`: Returns total pending payout (staked + rewards)
- `getCurrentClaimableAmount(address user)`: Returns amount currently available to claim
- `hasClaimableRewards(address user)`: Returns true if user has matured positions
- `getNextRewardDate(address user)`: Returns timestamp of next payout date
- `getNextRewardAmount(address user)`: Returns amount of next payout

### Contract Information
- `getConfig()`: Returns current configuration
- `getTotalStaked()`: Returns total amount staked across all users
