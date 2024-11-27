// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LPNRegistryV1} from "../LPNRegistryV1.sol";
import {QueryOutput, QueryInput} from "../Groth16VerifierExtension.sol";

/// @title LPNRegistryV1TestHelper
/// @notice A registry contract where groth-16 verification is skipped
/// @dev XXX testing purposes only XXX
/// @dev we want to mock as few functions as possible here to get us as close to the real deal as possible in testing
contract LPNRegistryV1TestHelper is LPNRegistryV1 {
    function processQuery(bytes32[] calldata data, QueryInput memory query)
        public
        view
        override
        returns (QueryOutput memory)
    {}
}
