// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct QueryOutput {
    // Total number of the all matching rows
    uint256 totalMatchedRows;
    // Returned rows of the current cursor
    bytes[] rows;
    // Query error, return NoError if none.
    QueryErrorCode error;
}

// Query errors
enum QueryErrorCode {
    // No error
    NoError,
    // A computation overflow error during the query process
    ComputationOverflow
}

interface ILPNRegistryV1 {
    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256);
}

error CallbackNotAuthorized();

contract LPNClientExample {
    ILPNRegistryV1 public lpnRegistry;

    event NewResponse(uint256 requestId, QueryOutput result);

    modifier onlyLagrangeRegistry() {
        if (msg.sender != address(lpnRegistry)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    constructor(address _lpnRegistry) {
        lpnRegistry = ILPNRegistryV1(_lpnRegistry);
    }

    function lpnCallback(uint256 requestId, QueryOutput memory result)
        external
        onlyLagrangeRegistry
    {
        emit NewResponse(requestId, result);
    }

    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable {
        lpnRegistry.request{value: msg.value}(
            queryHash, placeholders, startBlock, endBlock
        );
    }
}
