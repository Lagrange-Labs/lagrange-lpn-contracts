// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LATokenBase} from "./LATokenBase.sol";

/// @title LAToken
/// @dev Implementation of the upgradable LA Token
/// @dev This verstion is deployed on all evm chains other than eth mainnet
contract LAToken is LATokenBase {
    /// @notice Disable initializers on the logic contract
    constructor(address lzEndpoint) LATokenBase(lzEndpoint) {}

    /// @notice Initializes the token with name, symbol, and roles
    /// @param defaultAdmin The address that will be granted the DEFAULT_ADMIN_ROLE
    function initialize(address defaultAdmin) external {
        __LATokenBase_init(defaultAdmin);
    }
}
