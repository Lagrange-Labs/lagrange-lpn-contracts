// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {
    LPNClientV1,
    ILPNRegistryV1,
    QueryOutput,
    QueryErrorCode,
    QueryExecutionError
} from "../client/SDK.sol";

struct RequestData {
    /// @dev Address of the token holder for which the request is made
    address holder;
    /// @dev The number of blocks included in the query
    uint256 blockRange;
}

/// @dev Multiplier applied while computing the query result
uint256 constant PRECISION_MULTIPLIER = 10 ** 18;

/// @notice A contract that mints/rewards ERC20 tokens based on proportional balance of a different ERC20
contract ERC20Distributor is MockERC20, LPNClientV1 {
    /// @notice Columns expected in the query result
    struct ExpectedResultRow {
        uint256 integral;
    }

    /// @dev An example query hash that can be overridden when calling `initiateClaim`
    bytes32 public constant AVG_BALANCE_QUERY_HASH =
        0xeffca84cd99e1c088589a69e04692374fa600b6caa6fa1f16902bae9840de244;

    /// @dev The ERC20 contract that is being queried
    IERC20 public constant ERC20_TO_BE_QUERIED =
        IERC20(0x41Cb19D0Aa2e7Ea16F75030F25163D4184f26b7d);

    /// @dev Allocate 1 reward token per 1% of supply per block
    uint256 REWARD_RATE = 100 ether;

    /// @notice The farming campaign lasts for 1 month
    uint256 public constant CAMPAIGN_START_BLOCK = 2341753;
    uint256 public constant CAMPAIGN_END_BLOCK = 2557753;

    /// @notice Mapping from request ID to the campaign ID and holder it is made for
    mapping(uint256 => RequestData) public requestData;

    mapping(address holder => uint256 lastBlockClaimed) public lastClaimed;

    constructor(ILPNRegistryV1 lpnRegistry_) {
        MockERC20.initialize("Reward Token", "RTOKE", 18);
        LPNClientV1._initialize(lpnRegistry_);
    }

    /// @notice Function that initiates a query for an average balance over the block range
    /// @param holder Address of the token holder to query
    /// @param queryHash_ Optionally allow queryHash to be overridden for demo purposes
    /// @param placeholders_ Optionally allow placeholders to be overridden for demo purposes
    /// @param startBlock_ Optionally allow startBlock to be overridden for demo purposes
    /// @param endBlock_ Optionally allow endBlock to be overridden for demo purposes
    function initiateClaim(
        address holder,
        bytes32 queryHash_,
        bytes32[] calldata placeholders_,
        uint256 startBlock_,
        uint256 endBlock_
    ) external payable {
        bytes32 queryHash =
            queryHash_ == bytes32(0) ? AVG_BALANCE_QUERY_HASH : queryHash_;

        bytes32[] memory placeholders;

        if (placeholders_.length == 0) {
            placeholders = new bytes32[](2);
            placeholders[0] = addressToBytes32(holder);
            placeholders[1] = bytes32(PRECISION_MULTIPLIER);
        } else {
            placeholders = placeholders_;
        }

        uint256 lastBlockClaimed = lastClaimed[holder];

        uint256 startBlock = startBlock_ == 0
            ? max(lastBlockClaimed, CAMPAIGN_START_BLOCK)
            : startBlock_;

        uint256 endBlock = endBlock_ == 0
            ? min(block.number, CAMPAIGN_END_BLOCK) - 1
            : endBlock_;

        uint256 requestId = lpnRegistry.request{value: lpnRegistry.gasFee()}(
            queryHash, placeholders, startBlock, endBlock
        );

        lastClaimed[holder] = endBlock;
        requestData[requestId] =
            RequestData({holder: holder, blockRange: endBlock - startBlock + 1});
    }

    /// @notice Callback function called by the LPNRegistry contract.
    /// @param requestId The ID of the request.
    /// @param result The result of the request.
    function processCallback(uint256 requestId, QueryOutput memory result)
        internal
        override
    {
        if (result.error != QueryErrorCode.NoError) {
            revert QueryExecutionError(result.error);
        }

        if (result.rows.length == 0) return;

        uint256 integral =
            abi.decode(result.rows[0], (ExpectedResultRow)).integral;

        if (integral == 0) return;

        RequestData memory ctx = requestData[requestId];

        uint256 avgProportionPerBlock =
            integral / ERC20_TO_BE_QUERIED.totalSupply();

        uint256 amount = avgProportionPerBlock * REWARD_RATE * ctx.blockRange
            / PRECISION_MULTIPLIER;

        _mint(ctx.holder, amount);
    }

    function addressToBytes32(address addr) private pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? b : a;
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }
}
