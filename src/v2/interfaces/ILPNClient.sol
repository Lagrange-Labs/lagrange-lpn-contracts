// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryOutput} from "../Groth16VerifierExtension.sol";

/**
 * @title ILPNClient
 * @notice Interface for the LPNClient contract.
 */
interface ILPNClient {
    /// @notice Callback function called by the LPNRegistry contract.
    /// @param requestId The ID of the request.
    /// @param result The result of the request.
    function lpnCallback(uint256 requestId, QueryOutput memory result)
        external;
}
