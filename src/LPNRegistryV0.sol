// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LPNClientV0} from "./LPNClientV0.sol";

error NotAuthorized();

enum OperationType {
    AVERAGE
}

contract LPNRegistryV0 {
    uint256 public requestId;
    mapping(address whitelisted => bool) public whitelist;
    mapping(uint256 requestId => address client) public requests;

    event NewRegistration(address client, uint256 mappingSlot, uint256 lengthSlot);
    event NewRequest(
        uint256 requestId, address account, bytes32 key, uint256 startBlock, uint256 endBlock, OperationType op
    );

    modifier onlyWhitelist() {
        if (!whitelist[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    function register(uint256 mappingSlot, uint256 lengthSlot) external onlyWhitelist {
        emit NewRegistration(msg.sender, mappingSlot, lengthSlot);
    }

    function request(address account, bytes32 key, uint256 startBlock, uint256 endBlock, OperationType op)
        external
        onlyWhitelist
        returns (uint256)
    {
        unchecked {
            requestId++;
        }

        requests[requestId] = msg.sender;
        emit NewRequest(requestId, account, key, startBlock, endBlock, op);

        return requestId;
    }

    function response(uint256 _requestId, uint256 result) external {
        // TODO: Verify proof

        address client = requests[_requestId];
        requests[requestId] = address(0);

        LPNClientV0(client).lpnCallback(_requestId, result);
    }
}
