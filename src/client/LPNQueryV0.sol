// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LPNClientV0} from "./LPNClientV0.sol";
import {ILPNRegistry} from "../interfaces/ILPNRegistry.sol";

contract LPNQueryV0 is LPNClientV0 {
    // Use this to store context from the request for processing the result in the callback
    mapping(uint256 requestId => RequestMetadata request) public requests;

    struct RequestMetadata {
        address sender;
        address queriedHolder;
        uint96 queriedBlockNumber;
    }

    event Query(address indexed sender, address indexed storageContract);
    event Result(uint256 indexed requestId, uint256[] results);

    constructor(ILPNRegistry lpnRegistry) LPNClientV0(lpnRegistry) {}

    // This function is used to query the nft ids of a specific owner over a range of blocks.
    function query(
        address storageContract,
        address holder,
        uint256 startBlock,
        uint256 endBlock,
        uint256 offset
    ) external payable {
        uint256 requestId = lpnRegistry.request{value: lpnRegistry.GAS_FEE()}(
            storageContract,
            bytes32(uint256(uint160(holder))),
            startBlock,
            endBlock,
            offset
        );

        requests[requestId] = RequestMetadata({
            sender: msg.sender,
            queriedHolder: holder,
            queriedBlockNumber: uint96(endBlock)
        });

        emit Query(msg.sender, storageContract);
    }

    // This function is called by the LPN registry to provide the result of our query above.
    function processCallback(uint256 requestId, uint256[] calldata results)
        internal
        override
    {
        bool isHolder = results.length > 0;

        RequestMetadata memory req = requests[requestId];

        if (isHolder) {
            emit Result(requestId, results);
        } else {
            emit Result(requestId, results);
        }
    }
}
