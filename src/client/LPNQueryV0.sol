// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LPNClientV0} from "./LPNClientV0.sol";
import {ILPNRegistry} from "../interfaces/ILPNRegistry.sol";

/**
 * @title LPNQueryV0
 * @dev A contract for querying NFT ownership using LPN (Light Prover Node) protocol.
 */
contract LPNQueryV0 is LPNClientV0 {
    /**
     * @dev Struct to store metadata about a query request.
     * @param sender The address that sent the query request.
     * @param holder The address of the NFT holder being queried.
     */
    struct RequestMetadata {
        address sender;
        address holder;
    }

    /**
     * @dev Mapping to store request metadata by request ID.
     */
    mapping(uint256 requestId => RequestMetadata request) public requests;

    /**
     * @dev Event emitted when a query request is made.
     * @param sender The address that sent the query request.
     * @param storageContract The address of the NFT contract being queried.
     */
    event Query(address indexed sender, address indexed storageContract);

    /**
     * @dev Event emitted when the result of a query is received.
     * @param requestId The ID of the query request.
     * @param sender The address that sent the query request.
     * @param holder The address of the NFT holder that was queried.
     * @param results The array of NFT IDs owned by the queried holder.
     */
    event Result(
        uint256 indexed requestId,
        address indexed sender,
        address indexed holder,
        uint256[] results
    );

    /**
     * @dev Constructor to initialize the LPNQueryV0 contract.
     * @param lpnRegistry The address of the LPN registry contract.
     */
    constructor(ILPNRegistry lpnRegistry) LPNClientV0(lpnRegistry) {}

    /**
     * @dev Function to query the NFT IDs of a specific owner over a range of blocks.
     * @param storageContract The address of the NFT contract to query.
     * @param holder The address of the NFT holder to query.
     * @param startBlock The starting block number for the query range.
     * @param endBlock The ending block number for the query range.
     * @param offset The offset for pagination of results.
     */
    function query(
        address storageContract,
        address holder,
        uint256 startBlock,
        uint256 endBlock,
        uint8 offset
    ) external payable {
        uint256 requestId = lpnRegistry.request{value: msg.value}(
            storageContract,
            bytes32(uint256(uint160(holder))),
            startBlock,
            endBlock,
            offset
        );

        requests[requestId] =
            RequestMetadata({sender: msg.sender, holder: holder});

        emit Query(msg.sender, storageContract);
    }

    /**
     * @dev Internal function called by LPNClientV0 to provide the result of a query.
     * @param requestId The ID of the query request.
     * @param results The array of NFT IDs owned by the queried holder.
     */
    function processCallback(uint256 requestId, uint256[] calldata results)
        internal
        override
    {
        RequestMetadata memory req = requests[requestId];
        emit Result(requestId, req.sender, req.holder, results);
        delete requests[requestId];
    }
}
