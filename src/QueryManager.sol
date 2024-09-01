// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Groth16VerifierExtensions} from "./Groth16VerifierExtensions.sol";
import {ILPNClient} from "./interfaces/ILPNClient.sol";
import {QueryParams} from "./utils/QueryParams.sol";
import {isCDK} from "./utils/Constants.sol";
import {L1BlockHash, L1BlockNumber} from "./utils/L1Block.sol";
import {isEthereum, isOPStack, isMantle, isCDK} from "./utils/Constants.sol";
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
    uint256 public constant MAX_QUERY_RANGE = 50_000;

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 public constant ETH_GAS_FEE = 0.005 ether;
    uint256 public constant OP_GAS_FEE = 0.00045 ether;
    uint256 public constant CDK_GAS_FEE = 0.00045 ether;
    /// @dev Mantle uses a custom gas token
    uint256 public constant MANTLE_GAS_FEE = 1.5 ether;

    /// @notice A counter that assigns unique ids for client requests.
    // TODO: Need to ensure this does not conflict with V0
    uint256 public requestId;

    /// @notice Mapping to track requests and their associated clients.
    mapping(uint256 requestId => Groth16VerifierExtensions.Query query) public
        requests;

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
        bytes calldata params,
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

        // TODO:
        // QueryParams.CombinedParams memory cp =
        //     QueryParams.combinedFromBytes32(params);
        //
        // requests[requestId] = Groth16VerifierExtensions.Query({
        //     contractAddress: storageContract,
        //     userAddress: cp.userAddress,
        //     minBlockNumber: uint96(startBlock),
        //     maxBlockNumber: uint96(endBlock),
        //     blockHash: blockHash,
        //     clientAddress: msg.sender,
        //     rewardsRate: cp.rewardsRate,
        //     identifier: cp.identifier
        // });
        //
        emit NewRequest(
            requestId,
            queryHash,
            msg.sender,
            params,
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
        Groth16VerifierExtensions.Query memory query = requests[requestId_];
        delete requests[requestId_];

        if (isEthereum()) {
            query.blockHash = blockhash(blockNumber);
        }

        uint256[] memory results =
            Groth16VerifierExtensions.processQuery(data, query);

        ILPNClient(query.clientAddress).lpnCallback(requestId_, results);

        emit NewResponse(requestId_, query.clientAddress, results);
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
