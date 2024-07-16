// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ILPNRegistry} from "./interfaces/ILPNRegistry.sol";
import {ILPNClient} from "./interfaces/ILPNClient.sol";
import {OwnableWhitelist} from "./utils/OwnableWhitelist.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Groth16VerifierExtensions} from "./Groth16VerifierExtensions.sol";
import {L1BlockHash, L1BlockNumber} from "./utils/L1Block.sol";
import {isEthereum, isOPStack, isMantle} from "./utils/Constants.sol";
import {QueryParams} from "./utils/QueryParams.sol";

/// @notice Error thrown when attempting to register a storage contract more than once.
error ContractAlreadyRegistered();

/// @notice Error thrown when attempting to query a storage contract that is not registered.
error QueryUnregistered();

/// @notice Error thrown when attempting to query a block number that has not been indexed yet.
/// @dev startBlock < indexStart[storageContract]
error QueryBeforeIndexed();

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

/// @title LPNRegistryV0
/// @notice A registry contract for managing LPN (Lagrange Proving Network) clients and requests.
contract LPNRegistryV0 is ILPNRegistry, OwnableWhitelist, Initializable {
    using QueryParams for QueryParams.NFTQueryParams;

    /// @notice The maximum number of blocks a query can be computed over
    uint256 public constant MAX_QUERY_RANGE = 50_000;

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 public constant ETH_GAS_FEE = 0.05 ether;
    uint256 public constant OP_GAS_FEE = 0.00045 ether;
    /// @dev Mantle uses a custom gas token
    uint256 public constant MANTLE_GAS_FEE = 1.5 ether;

    /// @notice A counter that assigns unique ids for client requests.
    uint256 public requestId;

    /// @notice Mapping to track requests and their associated clients.
    mapping(uint256 requestId => Groth16VerifierExtensions.Query query) public
        queries;

    /// @notice Mapping to track the first block indexed for a contract.
    mapping(address storageContract => uint256 genesisBlock) public indexStart;

    /// @notice Validates the query range for a storage contract.
    /// @param storageContract The address of the storage contract being queried.
    /// @param startBlock The starting block number of the query range.
    /// @param endBlock The ending block number of the query range.
    /// @dev Reverts with appropriate errors if the query range is invalid:
    ///      - QueryBeforeIndexed: If the starting block is before the first indexed block for the storage contract.
    ///      - QueryAfterCurrentBlock: If the ending block is after the current block number.
    ///      - QueryInvalidRange: If the starting block is greater than the ending block.
    ///      - QueryGreaterThanMaxRange: If the range (ending block - starting block) exceeds the maximum allowed range.
    modifier validateQueryRange(
        address storageContract,
        uint256 startBlock,
        uint256 endBlock
    ) {
        if (isEthereum()) {
            uint256 genesisBlock = indexStart[storageContract];

            if (genesisBlock == 0) {
                revert QueryUnregistered();
            }

            if (startBlock < genesisBlock) {
                revert QueryBeforeIndexed();
            }
        }

        if (endBlock > L1BlockNumber()) {
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

    modifier requireGasFee() {
        if (msg.value < gasFee()) {
            revert InsufficientGasFee();
        }
        _;
    }

    function initialize(address owner) external initializer {
        OwnableWhitelist._initialize(owner);
    }

    function register(
        address storageContract,
        uint256 mappingSlot,
        uint256 lengthSlot
    ) external onlyWhitelist(storageContract) {
        // TODO: the id for a storage contract should be hash(address, mappingSlot)
        if (indexStart[storageContract] != 0) {
            revert ContractAlreadyRegistered();
        }
        indexStart[storageContract] = block.number;
        emit NewRegistration(
            storageContract, msg.sender, mappingSlot, lengthSlot
        );
    }

    function request(
        address storageContract,
        bytes32 params,
        uint256 startBlock,
        uint256 endBlock
    )
        external
        payable
        requireGasFee
        validateQueryRange(storageContract, startBlock, endBlock)
        returns (uint256)
    {
        unchecked {
            requestId++;
        }

        uint256 proofBlock = 0;
        bytes32 blockHash = 0;

        if (!isEthereum()) {
            proofBlock = L1BlockNumber();
            blockHash = L1BlockHash();
        }

        QueryParams.CombinedParams memory cp =
            QueryParams.combinedFromBytes32(params);

        queries[requestId] = Groth16VerifierExtensions.Query({
            contractAddress: storageContract,
            userAddress: cp.userAddress,
            minBlockNumber: uint96(startBlock),
            maxBlockNumber: uint96(endBlock),
            blockHash: blockHash,
            clientAddress: msg.sender,
            rewardsRate: cp.rewardsRate,
            identifier: cp.identifier
        });

        emit NewRequest(
            requestId,
            storageContract,
            msg.sender,
            params,
            startBlock,
            endBlock,
            cp.offset,
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
        Groth16VerifierExtensions.Query memory query = queries[requestId_];
        delete queries[requestId_];

        if (isEthereum()) {
            query.blockHash = blockhash(blockNumber);
        }

        uint256[] memory results =
            Groth16VerifierExtensions.processQuery(data, query);

        ILPNClient(query.clientAddress).lpnCallback(requestId_, results);

        emit NewResponse(requestId_, query.clientAddress, results);
    }

    /// @notice The relayer withdraws all fees accumulated
    function withdrawFees() external onlyOwner returns (bool) {
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        return sent;
    }

    function gasFee() public view returns (uint256) {
        if (isEthereum()) {
            return ETH_GAS_FEE;
        }

        if (isOPStack() && !isMantle()) {
            return OP_GAS_FEE;
        }

        return MANTLE_GAS_FEE;
    }

    /// @notice Useful for backwards compatibility of prior contract version on Eth Mainnet
    function GAS_FEE() public view returns (uint256) {
        return gasFee();
    }
}
