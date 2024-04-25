// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ILPNRegistry} from "./interfaces/ILPNRegistry.sol";
import {ILPNClient} from "./interfaces/ILPNClient.sol";
import {OwnableWhitelist} from "./utils/OwnableWhitelist.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Groth16VerifierExtensions} from "./Groth16VerifierExtensions.sol";
import {
    isEthereum,
    isOPStack,
    L1BlockHash,
    L1BlockNumber
} from "./utils/L1Block.sol";

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
    /// @notice The maximum number of blocks a query can be computed over
    uint256 public constant MAX_QUERY_RANGE = 1000;

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 public constant ETH_GAS_FEE = 0.05 ether;
    uint256 public constant OP_GAS_FEE = 0.00015 ether;

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

        if (endBlock > block.number) {
            revert QueryAfterCurrentBlock();
        }
        if (startBlock > endBlock) {
            revert QueryInvalidRange();
        }
        if (endBlock - startBlock > MAX_QUERY_RANGE) {
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
        bytes32 key,
        uint256 startBlock,
        uint256 endBlock,
        uint256 offset
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
        if (isOPStack()) {
            proofBlock = L1BlockNumber();
        }

        queries[requestId] = Groth16VerifierExtensions.Query({
            contractAddress: storageContract,
            userAddress: address(uint160(uint256(key))),
            minBlockNumber: startBlock,
            maxBlockNumber: endBlock,
            blockHash: L1BlockHash(proofBlock),
            clientAddress: msg.sender
        });

        emit NewRequest(
            requestId,
            storageContract,
            msg.sender,
            key,
            startBlock,
            endBlock,
            offset,
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

        queries[requestId_] = Groth16VerifierExtensions.Query({
            contractAddress: address(0),
            userAddress: address(0),
            minBlockNumber: 0,
            maxBlockNumber: 0,
            blockHash: 0,
            clientAddress: address(0)
        });

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

        return OP_GAS_FEE;
    }
}
