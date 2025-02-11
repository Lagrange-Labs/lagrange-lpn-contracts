// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IVersioned
/// @notice Interface for contracts that need to be versioned
interface IVersioned {
    /// @notice Returns the semantic version of the contract
    /// @return version The version of the contract as a string, ex "1.2.3"
    function version() external view returns (string memory);
}
