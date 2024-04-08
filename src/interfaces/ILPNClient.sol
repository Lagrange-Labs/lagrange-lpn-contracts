// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILPNRegistry} from "./ILPNRegistry.sol";

/**
 * @title ILPNClient
 * @notice Interface for the LPNClientV0 contract.
 */
interface ILPNClient {
    /// @notice Callback function called by the LPNRegistry contract.
    /// @param requestId The ID of the request.
    /// @param results The result of the request.
    function lpnCallback(uint256 requestId, uint256[] calldata results)
        external;
}
