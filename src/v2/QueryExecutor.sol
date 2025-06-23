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
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin-contracts-5.2.0/access/Ownable2Step.sol";
import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";
import {IDatabaseManager} from "./interfaces/IDatabaseManager.sol";

/// @title QueryExecutor
/// @notice The contract that handles requesting and responding to queries
/// @dev Requests & responses are forwarded to this contract from the router contract
/// @dev Although this contract collects fees, it does not store them. The fees are transferred to the FeeCollector contract.
contract QueryExecutor is
    Groth16VerifierExtension,
    Ownable2Step,
    IQueryExecutor
{
    using SafeCast for uint256;

    struct QueryRequest {
        address client; // the address of the client who made the request
        uint32 callbackGasLimit; // the gas limit for the callback
        QueryInput input; // the input for the query
    }

    struct Config {
        uint8 protocolFeePPT; // an optional fraction of the gas & query fee to charge for the protocol (in parts per thousand)
        uint16 baseFeePercentage; // the percentage of the current base fee to use for fulfillment gas price
            // should be close to 100 for chains with low gas price volatility
        uint24 verificationGas; // the static gas cost of verifying the snark and other accounting logic
        uint24 queryPricePerBlock; // the price of a query per block
        uint24 protocolFeeFixed; // an optional fixed fee to charge for the protocol, in wei
        uint24 maxQueryRange; // the maximum number of blocks a query can be computed over
    }

    /// @dev not all L2s support reading the L1 blockhash. For those that can't we disable the blockhash verification
    bool public immutable SUPPORTS_L1_BLOCKDATA;

    /// @notice other contracts in the system
    address private immutable ROUTER;
    IDatabaseManager private immutable DB_MANAGER;
    address payable private immutable FEE_COLLECTOR;

    /// @notice A nonce for constructing new requestIDs
    uint256 private s_requestIDNonce;

    /// @notice The contract's configuration parameters
    Config private s_config;

    /// @notice Mapping to track requests
    mapping(uint256 requestId => QueryRequest query) private s_requests;

    /// @notice Event emitted when a new request is made.
    /// @param requestId The ID of the request.
    /// @param queryHash The identifier of the SQL query associated with the request.
    /// @param client The address of the client who made this request.
    /// @param placeholders Values for the numbered placeholders in the query.
    /// @param startBlock The starting block for the computation.
    /// @param endBlock The ending block for the computation.
    /// @param limit The limit for the query. (0 = no limit)
    /// @param offset The offset for the query. (0 = no offset)
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
        uint256 limit,
        uint256 offset,
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
    error InsufficientFee();

    /// @notice Error thrown when blockhash verification fails.
    error BlockhashMismatch();

    /// @notice Error thrown when a non-router address calls a router-only function
    error OnlyRouter();

    /// @notice Error thrown when a transfer fails.
    error TransferFailed();

    /// @notice Error thrown when a zero address is used in the constructor
    error CannotUseZeroAddress();

    modifier onlyRouter() {
        if (msg.sender != ROUTER) {
            revert OnlyRouter();
        }
        _;
    }

    /// @notice Constructor for the QueryExecutor contract
    /// @param initialOwner The address of the initial owner of the contract
    /// @param router The address of the router contract
    /// @param dbManager The address of the database manager (proxy) contract
    /// @param feeCollector The address of the fee collector contract
    constructor(
        address initialOwner,
        address router,
        address dbManager,
        address payable feeCollector,
        Config memory config
    ) Ownable(initialOwner) {
        if (
            router == address(0) || dbManager == address(0)
                || feeCollector == address(0)
        ) {
            revert CannotUseZeroAddress();
        }
        ROUTER = router;
        DB_MANAGER = IDatabaseManager(dbManager);
        FEE_COLLECTOR = feeCollector;
        s_config = config;
        SUPPORTS_L1_BLOCKDATA = supportsL1BlockData();
    }

    /// @inheritdoc IQueryExecutor
    function request(
        address client,
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) external payable onlyRouter returns (uint256) {
        Config memory config = s_config;

        _validateQueryRange(startBlock, endBlock, config.maxQueryRange);

        {
            // Note: getFee will also verify that the query hash is valid
            uint256 fee =
                getFee(queryHash, callbackGasLimit, endBlock - startBlock + 1);

            if (msg.value < fee) {
                revert InsufficientFee();
            }
        }

        uint256 requestId = uint256(
            keccak256(
                abi.encode(++s_requestIDNonce, address(this), block.chainid)
            )
        );

        s_requests[requestId] = QueryRequest({
            input: QueryInput({
                limit: limit.toUint32(),
                offset: offset.toUint32(),
                minBlockNumber: startBlock.toUint64(),
                maxBlockNumber: endBlock.toUint64(),
                blockHash: L1BlockHash(),
                computationalHash: queryHash,
                userPlaceholders: placeholders
            }),
            callbackGasLimit: callbackGasLimit.toUint32(),
            client: client
        });

        // Forward fee to fee collector
        {
            (bool success,) = FEE_COLLECTOR.call{value: msg.value}("");
            if (!success) {
                revert TransferFailed();
            }
        }

        emit NewRequest(
            requestId,
            queryHash,
            client,
            placeholders,
            startBlock,
            endBlock,
            limit,
            offset,
            msg.value,
            L1BlockNumber()
        );

        return requestId;
    }

    /// @inheritdoc IQueryExecutor
    function respond(uint256 requestId, bytes32[] calldata data)
        external
        onlyRouter
        returns (address, uint256, QueryOutput memory)
    {
        QueryRequest memory query = s_requests[requestId];
        delete s_requests[requestId];

        QueryOutput memory result = processQuery(data, query.input);

        emit NewResponse(requestId, query.client, result);

        return (query.client, uint256(query.callbackGasLimit), result);
    }

    /// @notice Set the configuration parameters
    /// @param config The new configuration parameters
    function setConfig(Config memory config) external onlyOwner {
        s_config = config;
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

    /// @notice Get a request by the request ID
    /// @param requestId The unique ID of the request
    /// @return query The request information
    function getRequest(uint256 requestId)
        external
        view
        returns (QueryRequest memory)
    {
        return s_requests[requestId];
    }

    /// @notice Get the current configuration parameters
    /// @return config The current configuration parameters
    function getConfig() external view returns (Config memory) {
        return s_config;
    }

    /// @notice Get the router contract address
    /// @return router The router contract address
    function getRouter() external view returns (address) {
        return ROUTER;
    }

    /// @notice Get the database manager contract address
    /// @return dbManager The database manager contract address
    function getDBManager() external view returns (address) {
        return address(DB_MANAGER);
    }

    /// @notice Get the fee collector contract address
    /// @return feeCollector The fee collector contract address
    function getFeeCollector() external view returns (address) {
        return FEE_COLLECTOR;
    }

    /// @notice Get the current fee for a query
    /// @param queryHash The hash of the query
    /// @param callbackGasLimit The gas limit for the callback
    /// @param blockRange The range of blocks to query
    /// @return fee The fee, in wei, for the query
    function getFee(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        uint256 blockRange
    ) public view returns (uint256) {
        if (!DB_MANAGER.isQueryActive(queryHash)) {
            revert InvalidQuery();
        }
        Config memory config = s_config;
        // more human readable version of the fee calculation below:
        // paymentAmount =
        //                 (
        //                   gasPrice * (verificationGas + callbackGas)
        //                   + blockRange * queryPricePerBlock
        //                 ) * (1 + protocolFeePercent)
        //                 + flatFee
        return (
            (
                (
                    (
                        (
                            block.basefee * config.baseFeePercentage
                                * (config.verificationGas + callbackGasLimit)
                        ) / 100
                            + (config.queryPricePerBlock * blockRange * 1 gwei)
                    ) * (1_000 + config.protocolFeePPT)
                ) / 1_000
            ) + config.protocolFeeFixed
        );
    }

    /// @notice Private function to validate the query range
    /// @param startBlock The starting block number of the query range
    /// @param endBlock The ending block number of the query range
    /// @param maxQueryRange The maximum allowed range between start and end blocks
    /// @dev Reverts with appropriate errors if the query range is invalid:
    ///      - QueryAfterCurrentBlock: If the ending block is after the current block number
    ///      - QueryInvalidRange: If the starting block is greater than the ending block
    ///      - QueryGreaterThanMaxRange: If the range exceeds the maximum allowed range
    function _validateQueryRange(
        uint256 startBlock,
        uint256 endBlock,
        uint256 maxQueryRange
    ) private view {
        if (SUPPORTS_L1_BLOCKDATA && endBlock > L1BlockNumber()) {
            revert QueryAfterCurrentBlock();
        }
        if (startBlock > endBlock) {
            revert QueryInvalidRange();
        }
        if (endBlock - startBlock + 1 > maxQueryRange) {
            revert QueryGreaterThanMaxRange();
        }
    }
}
