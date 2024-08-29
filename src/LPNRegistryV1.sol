// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OwnableWhitelist} from "./utils/OwnableWhitelist.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {RegistrationManager} from "./RegistrationManager.sol";
import {QueryManager} from "./QueryManager.sol";

/// @title LPNRegistryV1
/// @notice A registry contract for managing LPN (Lagrange Proving Network) registrations and requests.
contract LPNRegistryV1 is
    QueryManager,
    RegistrationManager,
    OwnableWhitelist,
    Initializable
{
    function initialize(address owner) external initializer {
        OwnableWhitelist._initialize(owner);
    }

    /// @dev Only owner can register tables currently
    function registerTable(
        bytes32 hash,
        address contractAddr,
        uint96 chainId,
        uint256 genesisBlock,
        string calldata name,
        string calldata schema
    ) external onlyOwner {
        // TODO: Implement payment model
        _registerTable(hash, contractAddr, chainId, genesisBlock, name, schema);
    }

    /// @notice The owner withdraws all fees accumulated
    function withdrawFees() external onlyOwner returns (bool) {
        return _withdrawFees();
    }
}
