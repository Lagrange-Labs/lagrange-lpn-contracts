// SPDX-License-Identifier: MIT
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

    /// @notice add a batch of addresses to the whitelist.
    /// @param addrs an array of addresses to add.
    function addToWhitelist(address[] calldata addrs) external onlyOwner {
        for (uint256 i; i < addrs.length; i++) {
            whitelist[addrs[i]] = true;
        }
    }

    /// @notice Remove a batch of addresses from the whitelist.
    /// @param addrs an array of addresses to remove.
    function removeFromWhitelist(address[] calldata addrs) external onlyOwner {
        for (uint256 i; i < addrs.length; i++) {
            delete whitelist[addrs[i]];
        }
    }
}
