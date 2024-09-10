// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// import {LPNClientV1} from "lagrange-lpn-contracts/src/v1/client/LPNClientV1.sol";
// import {ILPNRegistryV1} from
//     "lagrange-lpn-contracts/src/v1/interfaces/ILPNRegistryV1.sol";
// import {L1BlockNumber} from "lagrange-lpn-contracts/src/utils/L1Block.sol";
// import {QueryOutput} from
//     "lagrange-lpn-contracts/src/v1/Groth16VerifierExtensions.sol";

import {LPNClientV1} from "../client/LPNClientV1.sol";
import {ILPNRegistryV1} from "../interfaces/ILPNRegistryV1.sol";
import {L1BlockNumber} from "../../utils/L1Block.sol";
import {QueryOutput} from "../Groth16VerifierExtensions.sol";

contract YourContract is LPNClientV1 {
    /// YOUR QUERY: SELECT AVG(key) FROM pudgy_penguins_owners WHERE value = $1;
    bytes32 public constant YOUR_QUERY_HASH =
        0xb4ae7462039ec325e1fc805a91fb35c9505f350e609d4d53e1c6e4f3dbfe8997;

    struct YourExpectedRow {
        uint256 someColumnName;
    }

    mapping(uint256 requestId => bool contextForCallback) public requests;

    constructor(ILPNRegistryV1 lpnRegistry_) {
        LPNClientV1._initialize(lpnRegistry_);
    }

    function query() external {
        bytes32[] memory placeholders = new bytes32[](1);
        placeholders[0] = bytes32(bytes20(msg.sender));

        uint256 requestId = lpnRegistry.request{value: lpnRegistry.gasFee()}(
            YOUR_QUERY_HASH, placeholders, L1BlockNumber(), L1BlockNumber()
        );

        requests[requestId] = true;
    }

    function processCallback(uint256 requestId, QueryOutput memory result)
        internal
        override
    {
        bool context = requests[requestId];

        uint256 someResult;
        for (uint256 i = 0; i < result.rows.length; i++) {
            YourExpectedRow memory row =
                abi.decode(result.rows[i], (YourExpectedRow));

            // Do something with the values in your result
            if (context) {
                someResult = row.someColumnName + 1;
            }
        }

        delete requests[requestId];
    }
}
