// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LPNClientV1} from "./LPNClientV1.sol";
import {ILPNRegistryV1} from "../interfaces/ILPNRegistryV1.sol";
import {QueryOutput} from "../Groth16VerifierExtension.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title LPNQueryV1
 * @dev A contract for submitting queries to the Lagrange ZK Coprocessor 1.0
 */
contract LPNQueryV1 is LPNClientV1, Initializable {
    /**
     * @dev Struct to store metadata about a query request.
     * @param sender The address that sent the query request.
     * @param queryHash The hash of the query sent. Uniquely identifies a query over a particular table.
     * @param placeholders An array of placeholder values for the query.
     */
    struct RequestMetadata {
        address sender;
        bytes32 queryHash;
        bytes32[] placeholders;
    }

    /**
     * @dev Mapping to store request metadata by request ID.
     */
    mapping(uint256 requestId => RequestMetadata request) public requests;

    /**
     * @dev Event emitted when a query request is made.
     * @param sender The address that sent the query request.
     * @param queryHash The hash of the query being made.
     * @param placeholders An array of placeholder values for the query.
     */
    event Query(
        address indexed sender,
        bytes32 indexed queryHash,
        bytes32[] placeholders
    );

    /**
     * @dev Event emitted when the result of a query is received.
     * @param requestId The ID of the query request.
     * @param sender The address that sent the query request.
     * @param result The output of the query.
     */
    event Result(
        uint256 indexed requestId, address indexed sender, QueryOutput result
    );

    /**
     * @dev Initializer for the LPNQueryV1 contract.
     * @param _lpnRegistry The address of the LPN registry contract.
     */
    function initialize(ILPNRegistryV1 _lpnRegistry) external initializer {
        LPNClientV1._initialize(_lpnRegistry);
    }

    /// @dev Function to submit a query to the Lagrange ZK Coprocessor.
    /// @param queryHash The hash of the query to be executed.
    /// @param placeholders An array of placeholder values for the query.
    /// @param startBlock The starting block number for the query range.
    /// @param endBlock The ending block number for the query range.
    // slither-disable-next-line arbitrary-send-eth
    function query(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint32 limit,
        uint32 offset
    ) external payable {
        uint256 requestId = lpnRegistry.request{value: lpnRegistry.gasFee()}(
            queryHash, placeholders, startBlock, endBlock, limit, offset
        );

        requests[requestId] = RequestMetadata({
            sender: msg.sender,
            queryHash: queryHash,
            placeholders: placeholders
        });

        emit Query(msg.sender, queryHash, placeholders);
    }

    /**
     * @dev Internal function called by LPNClientV1 to provide the result of a query.
     * @param requestId The ID of the query request.
     * @param result The output of the query.
     */
    function processCallback(uint256 requestId, QueryOutput memory result)
        internal
        override
    {
        RequestMetadata memory req = requests[requestId];
        emit Result(requestId, req.sender, result);
        delete requests[requestId];
    }
}
