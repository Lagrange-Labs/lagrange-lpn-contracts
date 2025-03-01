// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QueryExecutor} from "../../../src/v2/QueryExecutor.sol";
import {
    QueryOutput,
    QueryInput
} from "../../../src/v2/Groth16VerifierExtension.sol";
import {DatabaseManager} from "../../../src/v2/DatabaseManager.sol";
import {FeeCollector} from "../../../src/v2/FeeCollector.sol";

/// @title QueryExecutorTestHelper
/// @notice A test helper contract where groth-16 verification is skipped
/// @dev XXX testing purposes only XXX
/// @dev we want to mock as few functions as possible here to get us as close to the real deal as possible in testing
contract QueryExecutorTestHelper is QueryExecutor {
    constructor(
        address initialOwner,
        address router,
        address dbManager,
        address payable feeCollector,
        Config memory config
    ) QueryExecutor(initialOwner, router, dbManager, feeCollector, config) {}

    function processQuery(bytes32[] calldata data, QueryInput memory query)
        public
        view
        override
        returns (QueryOutput memory)
    {}

    /// @notice exposes the verifyBlockHash function for testing (it is internal)
    function verifyBlockhash(bytes32 blockHash, bytes32 expectedBlockHash)
        public
        view
    {
        super.verifyBlockHash(blockHash, expectedBlockHash);
    }
}
