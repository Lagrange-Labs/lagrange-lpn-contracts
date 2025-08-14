# Sūrya's Description Report

## Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| src/v2/client/LPNClientV2Example.sol | 9ed0da313dd2a727e86c67fcd42e765b7f4c61ee |
| src/v2/interfaces/IDatabaseManager.sol | 8b002521c6b0bee707bd6a230e7d55212a3cf393 |
| src/v2/interfaces/ILagrangeQueryRouter.sol | da7d89304fbd917fd0d40c6ba054355aac18decd |
| src/v2/interfaces/ILPNClient.sol | bbd19ce33d1ddd6033a7d61909e2bc60882c0be0 |
| src/v2/interfaces/IQueryExecutor.sol | ef4a7557d6be923f1514dfaef92fdd8bea2c7e00 |


## Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **LPNClientV2Example** | Implementation | ILPNClient |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | lpnCallback | External ❗️ | 🛑  | onlyLagrangeRouter |
| └ | request | External ❗️ |  💵 |NO❗️ |
| └ | request | External ❗️ |  💵 |NO❗️ |
||||||
| **IDatabaseManager** | Interface |  |||
| └ | isQueryActive | External ❗️ |   |NO❗️ |
| └ | registerQuery | External ❗️ | 🛑  |NO❗️ |
||||||
| **ILagrangeQueryRouter** | Interface |  |||
| └ | request | External ❗️ |  💵 |NO❗️ |
| └ | request | External ❗️ |  💵 |NO❗️ |
||||||
| **ILPNClient** | Interface |  |||
| └ | lpnCallback | External ❗️ | 🛑  |NO❗️ |
||||||
| **IQueryExecutor** | Interface |  |||
| └ | request | External ❗️ |  💵 |NO❗️ |
| └ | respond | External ❗️ | 🛑  |NO❗️ |
| └ | getFee | External ❗️ |   |NO❗️ |
| └ | getDBManager | External ❗️ |   |NO❗️ |


## Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
