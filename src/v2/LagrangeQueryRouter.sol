// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IQueryExecutor} from "./interfaces/IQueryExecutor.sol";
import {QueryOutput} from "./Groth16VerifierExtension.sol";
import {IVersioned} from "../interfaces/IVersioned.sol";

import {Initializable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.2.0/access/Ownable2StepUpgradeable.sol";
import {ILPNClient} from "./interfaces/ILPNClient.sol";
import {EnumerableSet} from
    "@openzeppelin-contracts-5.2.0/utils/structs/EnumerableSet.sol";

/// @title LagrangeQueryRouter
/// @notice Routes requests and responses to the appropriate QueryExecutor contract
/// @dev This contract is the entry point for all queries and responses
contract LagrangeQueryRouter is
    Initializable,
    Ownable2StepUpgradeable,
    IVersioned
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The semantic version of the contract
    string public constant VERSION = "1.0.0";

    /// @notice The default QueryExecutor contract
    /// @dev This is only used to route incoming requests, responses are routed by the address embedded in the requestId
    IQueryExecutor private s_defaultQueryExecutor;

    /// @notice Set of enabled query executors
    /// @dev The default query executor is always enabled, this set is used to disable/enable other executors that are used in tests, upgrades, etc
    EnumerableSet.AddressSet private s_enabledExecutors;

    /// @notice Event emitted when a new request is made
    /// @param requestId The ID of the request
    /// @param queryExecutor The address of the query executor that is handling the request
    /// @param client The address of the client that made the request
    event NewRequest(
        uint256 indexed requestId,
        address indexed queryExecutor,
        address indexed client
    );

    /// @notice Event emitted when a response is received
    /// @param requestId The ID of the request
    /// @param queryExecutor The address of the query executor that is validating the response
    /// @param client The address of the client that made the request, and is receiving the response
    /// @param success Whether the call to the client's callback was successful or not
    event NewResponse(
        uint256 indexed requestId,
        address indexed queryExecutor,
        address indexed client,
        bool success
    );

    /// @notice Error thrown when a QueryExecutor address is invalid
    error InvalidExecutorAddress();

    /// @notice Error thrown when trying to use a disabled executor
    error ExecutorNotEnabled();

    /// @notice Error thrown when trying to disable the default executor
    error CannotDisableDefaultExecutor();

    /// @notice We disable initializers to prevent the initializer from being called directly on the implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract, setting the initial owner and default query executor
    /// @param owner The initial owner of the contract
    /// @param queryExecutor The initial default QueryExecutor
    function initialize(address owner, IQueryExecutor queryExecutor)
        public
        initializer
    {
        __Ownable2Step_init();
        _transferOwnership(owner);
        _setDefaultQueryExecutor(queryExecutor);
    }

    /// @notice Makes an aggregation query request to the default QueryExecutor
    /// @param queryHash The hash of the query to execute
    /// @param callbackGasLimit The gas limit for the callback
    /// @param placeholders The placeholder values for the query
    /// @param startBlock The starting block number for the query range
    /// @param endBlock The ending block number for the query range
    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock
    ) external payable returns (uint256) {
        return _requestTo(
            s_defaultQueryExecutor,
            queryHash,
            callbackGasLimit,
            placeholders,
            startBlock,
            endBlock,
            0,
            0
        );
    }

    /// @notice Makes a query request to the default QueryExecutor
    /// @param queryHash The hash of the query to execute
    /// @param callbackGasLimit The gas limit for the callback
    /// @param placeholders The placeholder values for the query
    /// @param startBlock The starting block number for the query range
    /// @param endBlock The ending block number for the query range
    /// @param limit The maximum number of rows to return
    /// @param offset The number of rows to skip
    function request(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) external payable returns (uint256) {
        return _requestTo(
            s_defaultQueryExecutor,
            queryHash,
            callbackGasLimit,
            placeholders,
            startBlock,
            endBlock,
            limit,
            offset
        );
    }

    /// @notice Makes a request to a specific QueryExecutor
    /// @param executor The address of the QueryExecutor to use
    /// @param queryHash The hash of the query to execute
    /// @param callbackGasLimit The gas limit for the callback
    /// @param placeholders The placeholder values for the query
    /// @param startBlock The starting block number for the query range
    /// @param endBlock The ending block number for the query range
    /// @param limit The maximum number of rows to return
    /// @param offset The number of rows to skip
    /// @dev This function is intended for use in tests, upgrades, etc, not intended for users
    function requestTo(
        IQueryExecutor executor,
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) public payable returns (uint256) {
        if (!s_enabledExecutors.contains(address(executor))) {
            revert ExecutorNotEnabled();
        }

        return _requestTo(
            executor,
            queryHash,
            callbackGasLimit,
            placeholders,
            startBlock,
            endBlock,
            limit,
            offset
        );
    }

    /// @notice request handler for public request functiolns
    function _requestTo(
        IQueryExecutor executor,
        bytes32 queryHash,
        uint256 callbackGasLimit,
        bytes32[] calldata placeholders,
        uint256 startBlock,
        uint256 endBlock,
        uint256 limit,
        uint256 offset
    ) private returns (uint256) {
        uint256 requestId = executor.request{value: msg.value}(
            msg.sender,
            queryHash,
            callbackGasLimit,
            placeholders,
            startBlock,
            endBlock,
            limit,
            offset
        );

        emit NewRequest(requestId, address(executor), msg.sender);

        return requestId;
    }

    /// @notice Responds to a query request
    /// @param requestId The ID of the request to respond to
    /// @param executor The executor that will handle the response
    /// @param data The response data
    function respond(
        uint256 requestId,
        IQueryExecutor executor,
        bytes32[] calldata data
    ) external {
        if (!s_enabledExecutors.contains(address(executor))) {
            revert ExecutorNotEnabled();
        }

        (address client, uint256 callbackGasLimit, QueryOutput memory result) =
            executor.respond(requestId, data);

        bool success;
        try ILPNClient(client).lpnCallback{gas: callbackGasLimit}(
            requestId, result
        ) {
            success = true;
        } catch {}

        emit NewResponse(requestId, address(executor), client, success);
    }

    /// @notice Returns the fee for a query
    /// @param queryHash The hash of the query
    /// @param callbackGasLimit The gas limit for the callback
    /// @param blockRange The number of blocks to query
    /// @return fee The fee for the query
    function getFee(
        bytes32 queryHash,
        uint256 callbackGasLimit,
        uint256 blockRange
    ) external view returns (uint256) {
        return s_defaultQueryExecutor.getFee(
            queryHash, callbackGasLimit, blockRange
        );
    }

    /// @notice Updates the default QueryExecutor address
    /// @param queryExecutor The new default QueryExecutor contract
    function setDefaultQueryExecutor(IQueryExecutor queryExecutor)
        public
        onlyOwner
    {
        _setDefaultQueryExecutor(queryExecutor);
    }

    /// @notice Enables or disables a query executor
    /// @param executor The executor to enable/disable
    /// @param enabled Whether to enable or disable the executor
    /// @dev Cannot remove the default query executor
    function setExecutorEnabled(IQueryExecutor executor, bool enabled)
        external
        onlyOwner
    {
        if (address(executor) == address(s_defaultQueryExecutor) && !enabled) {
            revert CannotDisableDefaultExecutor();
        }
        if (enabled) {
            s_enabledExecutors.add(address(executor));
        } else {
            s_enabledExecutors.remove(address(executor));
        }
    }

    /// @notice Returns the default QueryExecutor address
    /// @return queryExecutor The default QueryExecutor address
    function getDefaultQueryExecutor()
        external
        view
        returns (IQueryExecutor queryExecutor)
    {
        return s_defaultQueryExecutor;
    }

    /// @notice Returns the list of enabled query executors
    /// @return queryExecutors The list of enabled query executors
    function getEnabledExecutors()
        external
        view
        returns (address[] memory queryExecutors)
    {
        return s_enabledExecutors.values();
    }

    /// @notice Updates the default QueryExecutor address
    /// @param queryExecutor The new default QueryExecutor contract
    function _setDefaultQueryExecutor(IQueryExecutor queryExecutor) private {
        if (address(queryExecutor) == address(0)) {
            revert InvalidExecutorAddress();
        }
        s_enabledExecutors.add(address(queryExecutor));
        s_defaultQueryExecutor = queryExecutor;
    }
}
