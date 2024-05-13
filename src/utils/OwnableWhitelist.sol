// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";

/// @notice Error thrown when an unauthorized caller attempts to perform an action.
error NotAuthorized();

/// @title OwnableWhitelist
/// @notice A contract for managing whitelisted addresses.
abstract contract OwnableWhitelist is Ownable {
    event Whitelisted(address addr, bool value);
    event BatchWhitelisted(address[] addrs, bool value);

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
        bool newState = !whitelist[client];
        whitelist[client] = newState;

        emit Whitelisted(client, newState);
    }

    /// @notice add a batch of addresses to the whitelist.
    /// @param addrs an array of addresses to add.
    function addToWhitelist(address[] calldata addrs) external onlyOwner {
        for (uint256 i; i < addrs.length; i++) {
            whitelist[addrs[i]] = true;
        }
        emit BatchWhitelisted(addrs, true);
    }

    /// @notice Remove a batch of addresses from the whitelist.
    /// @param addrs an array of addresses to remove.
    function removeFromWhitelist(address[] calldata addrs) external onlyOwner {
        for (uint256 i; i < addrs.length; i++) {
            delete whitelist[addrs[i]];
        }
        emit BatchWhitelisted(addrs, false);
    }
}
