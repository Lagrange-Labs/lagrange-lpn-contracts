// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    Groth16VerifierExtensions,
    QueryInput,
    QueryOutput
} from "./Groth16VerifierExtensions.sol";
import {ILPNClientV1} from "./interfaces/ILPNClientV1.sol";
import {isCDK} from "../utils/Constants.sol";
import {L1BlockHash, L1BlockNumber} from "../utils/L1Block.sol";
import {isEthereum, isOPStack, isMantle, isCDK} from "../utils/Constants.sol";
import {IQueryManager} from "./interfaces/IQueryManager.sol";

/// @notice Error thrown when attempting to query a block number that is after the current block.
/// @dev endBlock > block.number
error QueryAfterCurrentBlock();

/// @notice Error thrown when attempting to query a range that exceeds the maximum allowed range.
/// @dev endBlock - startBlock > MAX_QUERY_RANGE
error QueryGreaterThanMaxRange();

/// @notice Error thrown when attempting to query an invalid range.
/// @dev startBlock > endBlock
error QueryInvalidRange();

/// @notice Error thrown when gas fee is not paid.
error InsufficientGasFee();

/// @title QueryManager
/// @notice TODO
contract QueryManager is IQueryManager {
    /// @notice The maximum number of blocks a query can be computed over
    uint256 public constant MAX_QUERY_RANGE = 1_000;

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 public constant ETH_GAS_FEE = 0.01 ether;
    uint256 public constant OP_GAS_FEE = 0.001 ether;
    uint256 public constant CDK_GAS_FEE = 0.001 ether;
    /// @dev Mantle uses a custom gas token
    uint256 public constant MANTLE_GAS_FEE = 4.0 ether;

    /// @notice A counter that assigns unique ids for client requests.
    // TODO: Need to ensure this does not conflict with V0
    uint256 public requestId;

    struct QueryRequest {
        address client;
        QueryInput input;
    }

    /// @notice Mapping to track requests and their associated clients.
    mapping(uint256 requestId => QueryRequest query) public requests;

    /// @dev Reserves storage slots for future upgrades
    uint256[48] private __gap;

    modifier requireGasFee() {
        if (msg.value < gasFee()) {
            revert InsufficientGasFee();
        }
        _;
    }

    /// @notice Validates the query range for a storage contract.
    /// @param startBlock The starting block number of the query range.
    /// @param endBlock The ending block number of the query range.
    /// @dev Reverts with appropriate errors if the query range is invalid:
    ///      - QueryAfterCurrentBlock: If the ending block is after the current block number.
    ///      - QueryInvalidRange: If the starting block is greater than the ending block.
    ///      - QueryGreaterThanMaxRange: If the range (ending block - starting block) exceeds the maximum allowed range.
    modifier validateQueryRange(uint256 startBlock, uint256 endBlock) {
        if (!isCDK() && endBlock > L1BlockNumber()) {
            revert QueryAfterCurrentBlock();
        }
        if (startBlock > endBlock) {
            revert QueryInvalidRange();
        }
        if (endBlock - startBlock + 1 > MAX_QUERY_RANGE) {
            revert QueryGreaterThanMaxRange();
        }
        _;
    }

    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    )
        external
        payable
        requireGasFee
        validateQueryRange(startBlock, endBlock)
        returns (uint256)
    {
        unchecked {
            requestId++;
        }

        uint256 proofBlock = 0;
        bytes32 blockHash = 0;

        // TODO: Maybe store proofBlock for L1 queries as well
        if (!isEthereum()) {
            proofBlock = L1BlockNumber();
            blockHash = L1BlockHash();
        }

        requests[requestId] = QueryRequest({
            input: QueryInput({
                // TODO:
                limit: 0,
                // TODO:
                offset: 0,
                minBlockNumber: uint64(startBlock),
                maxBlockNumber: uint64(endBlock),
                blockHash: blockHash,
                computationalHash: queryHash,
                userPlaceholders: placeholders
            }),
            client: msg.sender
        });

        // TODO: Limit and offset separate from placeholders ?
        emit NewRequest(
            requestId,
            queryHash,
            msg.sender,
            placeholders,
            startBlock,
            endBlock,
            msg.value,
            proofBlock
        );

        return requestId;
    }

    function respond(
        uint256 requestId_,
        bytes32[] calldata data,
        uint256 blockNumber
    ) external {
        QueryRequest memory query = requests[requestId_];
        delete requests[requestId_];

        if (isEthereum()) {
            query.input.blockHash = blockhash(blockNumber);
        }

        QueryOutput memory result =
            Groth16VerifierExtensions.processQuery(data, query.input);

        ILPNClientV1(query.client).lpnCallback(requestId_, result);

        emit NewResponse(requestId_, query.client, result);
    }

    function gasFee() public view returns (uint256) {
        if (isEthereum()) {
            return ETH_GAS_FEE;
        }

        if (isMantle()) {
            return MANTLE_GAS_FEE;
        }

        if (isOPStack()) {
            return OP_GAS_FEE;
        }

        if (isCDK()) {
            return CDK_GAS_FEE;
        }

        revert("Chain not supported");
    }

    /// @notice The relayer withdraws all fees accumulated
    function _withdrawFees() internal returns (bool) {
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        return sent;
    }
}
