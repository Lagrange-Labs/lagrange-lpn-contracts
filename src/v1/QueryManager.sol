// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    Groth16VerifierExtension,
    QueryInput,
    QueryOutput
} from "./Groth16VerifierExtension.sol";
import {ILPNClientV1} from "./interfaces/ILPNClientV1.sol";
import {supportsL1BlockData} from "../utils/Constants.sol";
import {L1BlockHash, L1BlockNumber} from "../utils/L1Block.sol";
import {IQueryManager} from "./interfaces/IQueryManager.sol";
import {
    isEthereum,
    isMantle,
    isLocal,
    isOPStack,
    isCDK,
    isScroll
} from "../utils/Constants.sol";

/// @title QueryManager
/// @notice TODO
abstract contract QueryManager is IQueryManager, Groth16VerifierExtension {
    /// @notice The maximum number of blocks a query can be computed over
    uint256 public constant MAX_QUERY_RANGE = 50_000;

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 private immutable GAS_FEE;
    uint256 private constant ETH_GAS_FEE = 0.01 ether;
    uint256 private constant L2_GAS_FEE = 0.001 ether;
    /// @dev Mantle uses a custom gas token
    uint256 public constant MANTLE_GAS_FEE = 4.0 ether;

    /// @notice A counter that assigns unique ids for client requests.
    // TODO: Need to ensure this does not conflict with V0
    uint256 public requestId;

    /// @dev not all L2s support reading the L1 blockhash. For those that can't we disable the blockhash verification
    bool public immutable SUPPORTS_L1_BLOCKDATA;

    struct QueryRequest {
        address client;
        QueryInput input;
    }

    /// @notice Mapping to track requests and their associated clients.
    mapping(uint256 requestId => QueryRequest query) public requests;

    /// @dev Reserves storage slots for future upgrades
    uint256[48] private __gap;

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

    /// @notice Error thrown when blockhash verification fails.
    error BlockhashMismatch();

    /// @notice Error thrown when deloyed to a chain with an unknown chainId.
    error ChainNotSupported();

    modifier requireGasFee() {
        if (msg.value < GAS_FEE) {
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
        if (SUPPORTS_L1_BLOCKDATA && endBlock > L1BlockNumber()) {
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

    constructor() {
        SUPPORTS_L1_BLOCKDATA = supportsL1BlockData();
        if (isEthereum() || isLocal()) {
            GAS_FEE = ETH_GAS_FEE;
        } else if (isMantle()) {
            GAS_FEE = MANTLE_GAS_FEE;
        } else if (isOPStack() || isCDK() || isScroll()) {
            GAS_FEE = L2_GAS_FEE;
        } else {
            revert ChainNotSupported();
        }
    }

    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256) {
        return request(queryHash, placeholders, startBlock, endBlock, 0, 0);
    }

    function request(
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint32 limit,
        uint32 offset
    )
        public
        payable
        requireGasFee
        validateQueryRange(startBlock, endBlock)
        returns (uint256)
    {
        unchecked {
            requestId++;
        }

        requests[requestId] = QueryRequest({
            input: QueryInput({
                limit: limit,
                offset: offset,
                minBlockNumber: uint64(startBlock),
                maxBlockNumber: uint64(endBlock),
                blockHash: L1BlockHash(),
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
            L1BlockNumber()
        );

        return requestId;
    }

    function respond(
        uint256 requestId_,
        bytes32[] calldata data,
        uint256 // TODO - remove
    ) external {
        QueryRequest memory query = requests[requestId_];
        delete requests[requestId_];

        QueryOutput memory result = processQuery(data, query.input);

        ILPNClientV1(query.client).lpnCallback(requestId_, result);

        emit NewResponse(requestId_, query.client, result);
    }

    function gasFee() public view returns (uint256) {
        return GAS_FEE;
    }

    /// @inheritdoc Groth16VerifierExtension
    function verifyBlockHash(bytes32 blockHash, bytes32 expectedBlockHash)
        internal
        view
        override
    {
        if (SUPPORTS_L1_BLOCKDATA && blockHash != expectedBlockHash) {
            revert BlockhashMismatch();
        }
    }
}
