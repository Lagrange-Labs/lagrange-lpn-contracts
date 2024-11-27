// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LPNClientV1} from "./LPNClientV1.sol";
import {ILPNRegistryV1} from "../interfaces/ILPNRegistryV1.sol";
import {QueryOutput, QueryErrorCode} from "../Groth16VerifierExtension.sol";

/// @dev Errors that occur while computing and proving the query result in the ZK Coprocessor
error QueryExecutionError(QueryErrorCode errorCode);
