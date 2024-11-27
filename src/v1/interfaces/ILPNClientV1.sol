// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryOutput} from "../Groth16VerifierExtension.sol";

/**
 * @title ILPNClientV1
 * @notice Interface for the LPNClientV1 contract.
 */
interface ILPNClientV1 {
    /// @notice Callback function called by the LPNRegistry contract.
    /// @param requestId The ID of the request.
    /// @param result The result of the request.
    function lpnCallback(uint256 requestId, QueryOutput memory result)
        external;
}
