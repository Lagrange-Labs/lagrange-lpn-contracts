// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    Groth16VerifierExtension,
    QueryInput,
    QueryOutput
} from "./Groth16VerifierExtension.sol";
import {supportsL1BlockData} from "../utils/Constants.sol";
import {IQueryExecutor} from "./interfaces/IQueryExecutor.sol";
import {L1BlockHash, L1BlockNumber} from "../utils/L1Block.sol";
import {DatabaseManager} from "./DatabaseManager.sol";
import {FeeCollector} from "./FeeCollector.sol";
import {
    isEthereum,
    isMantle,
    isLocal,
    isOPStack,
    isCDK,
    isScroll
} from "../utils/Constants.sol";
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";

/// @title QueryExecutor
/// @notice The contract that handles requesting and responding to queries
/// @dev Requests & responses are forwarded to this contract from the router contract
/// @dev This contract does not emit events - that is handled by the router
/// @dev Although this contract collects fees, it does not store them. The fees are transferred to the FeeCollector contract.
contract QueryExecutor is
    Groth16VerifierExtension,
    Ownable2Step,
    IQueryExecutor
{
    /// @notice The maximum number of blocks a query can be computed over
    uint256 public constant MAX_QUERY_RANGE = 50_000; // TODO should this be configurable per query? Or is one global parameter okay?

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 public immutable GAS_FEE;
    uint256 private constant ETH_GAS_FEE = 0.01 ether;
    uint256 private constant L2_GAS_FEE = 0.001 ether;
    /// @dev Mantle uses a custom gas token
    uint256 private constant MANTLE_GAS_FEE = 4.0 ether;

    /// @dev not all L2s support reading the L1 blockhash. For those that can't we disable the blockhash verification
    bool public immutable SUPPORTS_L1_BLOCKDATA;

    /// @notice other contracts in the system
    address public immutable router;
    DatabaseManager public immutable dbManager;
    FeeCollector public immutable feeCollector;

    /// @notice A nonce for constructing new requestIDs
    uint256 private s_requestIDNonce;

    struct QueryRequest {
        address client;
        QueryInput input;
    }

    /// @notice Mapping to track requests and their associated clients.
    mapping(uint256 requestId => QueryRequest query) private s_requests;

    /// @notice Event emitted when a new request is made.
    /// @param requestId The ID of the request.
    /// @param queryHash The identifier of the SQL query associated with the request.
    /// @param client The address of the client who made this request.
    /// @param placeholders Values for the numbered placeholders in the query.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @param fee The gas fee paid for the request.
    /// @param proofBlock The requested block for the proof to be computed against.
    ///                   Currently required for OP Stack chains
    event NewRequest(
        uint256 indexed requestId,
        bytes32 indexed queryHash,
        address indexed client,
        bytes32[] placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 fee,
        uint256 proofBlock
    );

    /// @notice Event emitted when a response is received.
    /// @param requestId The ID of the request.
    /// @param client The address of the client who made the request.
    /// @param result The computed results for the request.
    event NewResponse(
        uint256 indexed requestId, address indexed client, QueryOutput result
    );

    /// @notice Error thrown when attempting to query a block number that is after the current block.
    /// @dev endBlock > block.number
    error QueryAfterCurrentBlock();

    /// @notice Error thrown when attempting to query a range that exceeds the maximum allowed range.
    /// @dev endBlock - startBlock > MAX_QUERY_RANGE
    error QueryGreaterThanMaxRange();

    /// @notice Error thrown when attempting to query an invalid range.
    /// @dev startBlock > endBlock
    error QueryInvalidRange();

    /// @notice Error thrown when attempting to query an invalid query.
    error InvalidQuery();

    /// @notice Error thrown when gas fee is not paid.
    error InsufficientGasFee();

    /// @notice Error thrown when blockhash verification fails.
    error BlockhashMismatch();

    /// @notice Error thrown when deloyed to a chain with an unknown chainId.
    error ChainNotSupported();

    /// @notice Error thrown when a non-router address calls a router-only function
    error OnlyRouter();

    /// @notice Error thrown when a transfer fails.
    error TransferFailed();

    modifier requireGasFee() {
        if (msg.value < GAS_FEE) {
            revert InsufficientGasFee();
        }
        _;
    }

    modifier onlyRouter() {
        if (msg.sender != router) {
            revert OnlyRouter();
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
            // NOTE: technically the max range is MAX_QUERY_RANGE-1 :facepalm:
            revert QueryGreaterThanMaxRange();
        }
        _;
    }

    /// @notice Constructor for the QueryExecutor contract
    /// @param initialOwner The address of the initial owner of the contract
    /// @param _router The address of the router contract
    /// @param _dbManager The address of the database manager (proxy) contract
    /// @param _feeCollector The address of the fee collector contract
    constructor(
        address initialOwner,
        address _router,
        address _dbManager,
        address payable _feeCollector
    ) Ownable(initialOwner) {
        router = _router;
        dbManager = DatabaseManager(_dbManager);
        feeCollector = FeeCollector(_feeCollector);
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

    /// @inheritdoc IQueryExecutor
    function request(
        address client,
        bytes32 queryHash,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint32 limit,
        uint32 offset
    )
        public
        payable
        onlyRouter
        requireGasFee
        validateQueryRange(startBlock, endBlock)
        returns (uint256)
    {
        if (!dbManager.isQueryActive(queryHash)) {
            revert InvalidQuery();
        }

        uint256 requestId = uint256(
            keccak256(
                abi.encodePacked(
                    ++s_requestIDNonce, address(this), block.chainid
                )
            )
        );

        s_requests[requestId] = QueryRequest({
            input: QueryInput({
                limit: limit,
                offset: offset,
                minBlockNumber: uint64(startBlock),
                maxBlockNumber: uint64(endBlock),
                blockHash: L1BlockHash(),
                computationalHash: queryHash,
                userPlaceholders: placeholders
            }),
            client: client
        });

        // Forward fee to fee collector
        (bool success,) =
            payable(address(feeCollector)).call{value: msg.value}("");
        if (!success) {
            revert TransferFailed();
        }

        emit NewRequest(
            requestId,
            queryHash,
            client,
            placeholders,
            startBlock,
            endBlock,
            msg.value,
            block.number
        );

        return requestId;
    }

    /// @inheritdoc IQueryExecutor
    function respond(uint256 requestId, bytes32[] calldata data)
        external
        onlyRouter
        returns (address, QueryOutput memory)
    {
        QueryRequest memory query = s_requests[requestId];
        delete s_requests[requestId];

        QueryOutput memory result = processQuery(data, query.input);

        emit NewResponse(requestId, query.client, result);

        return (query.client, result);
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

    function getRequest(uint256 requestId)
        public
        view
        returns (QueryRequest memory)
    {
        return s_requests[requestId];
    }
}
