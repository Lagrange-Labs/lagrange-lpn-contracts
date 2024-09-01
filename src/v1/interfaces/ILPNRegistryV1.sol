// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQueryManager} from "./IQueryManager.sol";
import {IRegistrationManager} from "./IRegistrationManager.sol";

interface ILPNRegistryV1 is IQueryManager, IRegistrationManager {
    /// @notice The gas fee paid for on request to reimburse the response transaction.
    function gasFee() external returns (uint256);
}
