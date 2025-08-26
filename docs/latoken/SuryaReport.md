# Sūrya's Description Report

## Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| src/latoken/LAEscrow.sol | 926861694dab236ad55209741f935520960df0e5 |
| src/latoken/LAPublicStaker.sol | b3c76c7f3d9cd4e972d9eddaf35bcd9854aeefa5 |
| src/latoken/LAToken.sol | d91dd8931a47f5ba9543242e273b8e85a0ae090d |
| src/latoken/LATokenBase.sol | 61445d5a876368ef749dfce179bab1e888a2f17e |
| src/latoken/LATokenDeployer.sol | 2788013102232dcf6742215be79da776b293c95c |
| src/latoken/LATokenMintable.sol | a62cbbd27534a011d464f8d2a923ec268a7ca7e8 |
| src/latoken/LATokenMintableDeployer.sol | c829980583f19d284e76222d2209f38bac5a15b7 |
| src/latoken/OFTUpgradable.sol | 1984bc9e2d89b649d90b6b9c754112f2c69ec109 |


## Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **LAEscrow** | Implementation | Initializable, Ownable2StepUpgradeable, IVersioned |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | Public ❗️ | 🛑  | initializer |
| └ | createAgreement | External ❗️ | 🛑  | onlyOwner |
| └ | activateAgreement | External ❗️ | 🛑  |NO❗️ |
| └ | claimRebates | External ❗️ | 🛑  |NO❗️ |
| └ | distribute | External ❗️ | 🛑  | onlyOwner |
| └ | cancelAgreement | External ❗️ | 🛑  | onlyOwner |
| └ | getEscrowAgreement | Public ❗️ |   |NO❗️ |
| └ | hasClaimableRebates | External ❗️ |   |NO❗️ |
| └ | getCurrentClaimableAmount | Public ❗️ |   |NO❗️ |
| └ | getNextRebateClaimDate | Public ❗️ |   |NO❗️ |
| └ | _processClaim | Private 🔐 |   | |
||||||
| **LAPublicStaker** | Implementation | Initializable, Ownable2StepUpgradeable, IVersioned |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | Public ❗️ | 🛑  | initializer |
| └ | setConfig | External ❗️ | 🛑  | onlyOwner |
| └ | stake | External ❗️ | 🛑  |NO❗️ |
| └ | claim | External ❗️ | 🛑  |NO❗️ |
| └ | distribute | External ❗️ | 🛑  |NO❗️ |
| └ | getConfig | Public ❗️ |   |NO❗️ |
| └ | getTotalStaked | Public ❗️ |   |NO❗️ |
| └ | getStakePositions | Public ❗️ |   |NO❗️ |
| └ | hasClaimableRewards | Public ❗️ |   |NO❗️ |
| └ | getCurrentClaimableAmount | Public ❗️ |   |NO❗️ |
| └ | getNextRewardDate | Public ❗️ |   |NO❗️ |
| └ | getNextRewardAmount | Public ❗️ |   |NO❗️ |
| └ | getTotalStaked | Public ❗️ |   |NO❗️ |
| └ | getTotalPendingRewards | Public ❗️ |   |NO❗️ |
| └ | getTotalPendingPayout | Public ❗️ |   |NO❗️ |
| └ | _setConfig | Private 🔐 | 🛑  | |
||||||
| **LAToken** | Implementation | LATokenBase |||
| └ | <Constructor> | Public ❗️ | 🛑  | LATokenBase |
| └ | initialize | External ❗️ | 🛑  | initializer |
||||||
| **LATokenBase** | Implementation | Initializable, OFTUpgradable |||
| └ | <Constructor> | Public ❗️ | 🛑  | OFTUpgradable |
| └ | __LATokenBase_init | Internal 🔒 | 🛑  | |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
||||||
| **LATokenDeployer** | Implementation |  |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
||||||
| **LATokenMintable** | Implementation | LATokenBase |||
| └ | <Constructor> | Public ❗️ | 🛑  | LATokenBase |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | availableToMint | Public ❗️ |   |NO❗️ |
| └ | mint | External ❗️ | 🛑  | onlyRole |
| └ | _getMintableStorage | Private 🔐 |   | |
||||||
| **LATokenMintableDeployer** | Implementation |  |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
||||||
| **OFTUpgradable** | Implementation | AccessControlDefaultAdminRulesUpgradeable, ERC20PermitUpgradeable, OFTCustomUpgradeable |||
| └ | <Constructor> | Public ❗️ | 🛑  | OFTCustomUpgradeable |
| └ | _oftBurn | Internal 🔒 | 🛑  | |
| └ | _oftMint | Internal 🔒 | 🛑  | |


## Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
