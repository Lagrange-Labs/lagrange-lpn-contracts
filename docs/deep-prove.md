# DeepProvePayments Contract

## Overview

The `DeepProvePayments` contract establishes escrow agreements between clients and Lagrange for LA tokens. This contract is not open to the public - escrow agreements are pre-established with specific clients by the contract owner. Users deposit LA tokens upfront and receive periodic rebate payments over a specified duration.

## Requirements

### Core Functionality
- **Pre-established Agreements**: Only owner can create escrow agreements for specific users
- **Token Deposit**: Users must deposit LA tokens to activate their agreement
- **Periodic Rebates**: Users receive rebate payments over time based on their agreement terms
- **Flexible Claims**: Users can claim all available rebates at any time
- **Treasury Integration**: Contract can pull additional funds from treasury for rebate payments

### Key Features
- **Owner-Controlled Setup**: Only contract owner can create and cancel agreements
- **User-Controlled Activation**: Users activate agreements by depositing required LA tokens
- **Time-Based Rebates**: Rebates are distributed over a specified number of days
- **Automatic Calculations**: Contract calculates available rebates based on time elapsed
- **Treasury Fallback**: Pulls funds from treasury if contract balance is insufficient

## Lifecycle

### 1. Agreement Creation

**Function**: `createAgreement(address user, NewEscrowAgreementParams params)`

1. Contract owner creates an escrow agreement for a specific user
2. Contract validates:
   - User address is not zero
   - Payment amount > 0
   - Rebate amount > 0
   - Duration days > 0
   - Number of rebates > 0
   - No existing agreement for the user
3. New agreement is stored with:
   - `paymentAmount`: LA tokens user must deposit (max ~300M LA)
   - `rebateAmount`: LA tokens per rebate claim
   - `durationDays`: Total duration for rebate period
   - `numRebates`: Total number of rebates available
   - `activationDate`: Set to 0 (inactive)
4. Event `NewAgreement` is emitted

**Parameters**:
```solidity
struct NewEscrowAgreementParams {
    uint88 paymentAmount;  // Amount of LA tokens to deposit
    uint88 rebateAmount;   // Amount per rebate claim
    uint16 durationDays;   // Rebate period duration
    uint16 numRebates;     // Total rebates available
}
```

### 2. Agreement Activation

**Function**: `activateAgreement()`

1. User with pre-established agreement calls activation
2. Contract validates:
   - Agreement exists for caller
   - Agreement not already activated
   - User has approved sufficient LA tokens
3. Agreement activation date is set to current timestamp
4. LA tokens are transferred from user to contract
5. Event `AgreementActivated` is emitted

**Requirements**:
- User must approve contract to spend `paymentAmount` of LA tokens
- Can only be called once per agreement

### 3. Rebate Claiming

**Function**: `claimRebates()`

1. User calls `claimRebates()` to collect available rebates
2. Contract calculates claimable rebates based on:
   - Time elapsed since activation
   - Number of rebates already claimed
   - Whether agreement period has ended
3. For final claim (after duration ends):
   - All remaining rebates are claimable
   - Agreement is deleted from storage
4. For regular claims:
   - Rebates based on time proportion are claimable
   - Agreement remains active with updated claim count
5. If contract balance is insufficient, pulls additional funds from treasury
6. Transfers total claimable amount to user
7. Event `RebateClaimed` is emitted

**Rebate Calculation**:
```
timeElapsed = currentTime - activationDate
rebatesPassed = (timeElapsed * numRebates) / totalDurationSeconds
claimableRebates = rebatesPassed - numRebatesClaimed
totalClaimable = claimableRebates * rebateAmount
```

### 4. Agreement Management

**Function**: `cancelAgreement(address user)`

- Only callable by owner
- Cancels future rebate claims for specified user
- Deletes agreement from storage
- Does not refund deposited tokens

## Distribution Function

**Function**: `distribute(address to, uint256 amount)`

The `distribute` function provides a direct distribution mechanism for the treasury to send LA tokens to specific recipients.

### Usage
- Only callable by the treasury address
- Transfers specified amount of LA tokens to recipient
- Emits `Distributed` event
- Validates recipient is not zero address and amount > 0

## View Functions

### Agreement Information
- `getEscrowAgreement(address user)`: Returns complete agreement details for a user
- `hasClaimableRebates(address user)`: Returns true if user has rebates available to claim
- `getCurrentClaimableAmount(address user)`: Returns amount currently available to claim
- `getNextRebateClaimDate(address user)`: Returns timestamp of next rebate availability

### Contract Information
- `VERSION`: Returns contract version ("1.0.0")
- `LA_TOKEN`: Returns address of the LA token contract
- `TREASURY`: Returns address of the treasury contract

## Data Structures

### EscrowAgreement
```solidity
struct EscrowAgreement {
    uint88 paymentAmount;      // Amount deposited by user
    uint88 rebateAmount;       // Amount per rebate
    uint16 durationDays;       // Total rebate period
    uint16 numRebates;         // Total rebates available
    uint16 numRebatesClaimed;  // Rebates already claimed
    uint32 activationDate;     // When agreement was activated
}
```

## Events

- `NewAgreement(address indexed user, EscrowAgreement agreement)`: Emitted when agreement is created
- `AgreementActivated(address indexed user)`: Emitted when user activates agreement
- `RebateClaimed(address indexed user, uint256 amount)`: Emitted when user claims rebates
- `Distributed(address indexed to, uint256 amount)`: Emitted when treasury distributes tokens

## Error Conditions

- `AgreementAlreadyActivated()`: Attempting to activate already active agreement
- `AgreementAlreadyExists()`: Creating agreement for user who already has one
- `InvalidAgreement()`: Operating on non-existent or invalid agreement
- `InvalidAmount()`: Zero amount provided where positive amount required
- `InvalidConfig()`: Invalid configuration parameters
- `InvalidRecipient()`: Zero address provided as recipient
- `NoClaimableRebates()`: No rebates available to claim
- `OnlyTreasuryCanDistribute()`: Non-treasury address attempting distribution
- `TransferFailed()`: Token transfer operation failed
- `ZeroAddress()`: Zero address provided where valid address required 