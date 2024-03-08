// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILPNRegistry, OperationType} from "./interfaces/ILPNRegistry.sol";
import {ILPNClient} from "./interfaces/ILPNClient.sol";

/// @notice Error thrown when an unauthorized caller attempts to perform an action.
error NotAuthorized();

/// @title LPNRegistryV0
/// @notice A registry contract for managing LPN (Lagrange Proving Network) clients and requests.
contract LPNRegistryV0 is ILPNRegistry {
    /// @notice A counter that assigns unique ids for client requests.
    uint256 public requestId;

    /// @notice Mapping to track whitelisted addresses.
    mapping(address => bool) public whitelist; // TODO: Do we need this?

    /// @notice Mapping to track requests and their associated clients.
    mapping(uint256 => address) public requests;

    /// @notice Modifier to restrict access to whitelisted addresses only.
    modifier onlyWhitelist() {
        if (!whitelist[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    function register(uint256 mappingSlot, uint256 lengthSlot)
        external
        onlyWhitelist
    {
        emit NewRegistration(msg.sender, mappingSlot, lengthSlot);
    }

    function request(
        address account,
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock,
        OperationType op
    ) external onlyWhitelist returns (uint256) {
        unchecked {
            requestId++;
        }
        requests[requestId] = msg.sender;
        emit NewRequest(requestId, account, key, startBlock, endBlock, op);
        return requestId;
    }

    function respond(uint256 _requestId, uint256 result) external {
        // TODO: Verify proof
        address client = requests[_requestId];
        requests[requestId] = address(0);
        ILPNClient(client).lpnCallback(_requestId, result);
    }
}
