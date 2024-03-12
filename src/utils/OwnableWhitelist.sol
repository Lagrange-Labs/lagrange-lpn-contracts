// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";

/// @notice Error thrown when an unauthorized caller attempts to perform an action.
error NotAuthorized();

/// @title OwnableWhitelist
/// @notice A contract for managing whitelisted addresses.
abstract contract OwnableWhitelist is Ownable {
    /// @notice Mapping to track whitelisted addresses.
    mapping(address => bool) public whitelist;

    /// @notice Modifier to restrict access to whitelisted addresses only.
    modifier onlyWhitelist(address someAddress) {
        if (!whitelist[someAddress]) {
            revert NotAuthorized();
        }
        _;
    }

    function _initialize(address owner) internal {
        _initializeOwner(owner);
    }

    function toggleWhitelist(address client) external onlyOwner {
        whitelist[client] = !whitelist[client];
    }
}
