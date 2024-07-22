// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {QueryParams} from "./utils/QueryParams.sol";
import {IPolygonZkEVMBridge} from
    "zkevm-contracts/interfaces/IPolygonZkEVMBridge.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @notice Error thrown when gas fee is not paid.
error InsufficientGasFee();

/// @title QueryBridge
/// @notice A contract to initiate an L2 query from L1 that contains the blockhash required to verify the query results
contract QueryBridge is Initializable {
    using QueryParams for QueryParams.NFTQueryParams;

    // Global Exit Root address
    IPolygonZkEVMBridge public polygonZkEVMBridge;

    // Address in the other network that will receive the message
    address public lpnRegistryAddress;

    /// @notice The maximum number of blocks a query can be computed over
    uint256 public constant MAX_QUERY_RANGE = 50_000;

    /// @notice A constant gas fee paid for each request to reimburse the relayer when it delivers the response
    uint256 public constant CDK_GAS_FEE = 0.00015 ether; // TODO: confirm price

    event BridgedQuery(bytes params);

    modifier requireGasFee() {
        if (msg.value < gasFee()) {
            revert InsufficientGasFee();
        }
        _;
    }

    /// @param polygonZkEVMBridge_ Polygon zkevm bridge address
    /// @param lpnRegistryAddress_ Lagrange Query Registry address on receiving chains
    function initialize(
        IPolygonZkEVMBridge polygonZkEVMBridge_,
        address lpnRegistryAddress_
    ) external initializer {
        polygonZkEVMBridge = polygonZkEVMBridge_;
        lpnRegistryAddress = lpnRegistryAddress_;
    }

    function requestCDK(
        uint32 destinationNetwork,
        address storageContract,
        bytes32 params,
        uint256 startBlock,
        uint256 endBlock
    ) external payable requireGasFee {
        uint256 proofBlock = block.number;
        bytes32 blockHash = blockhash(proofBlock);

        bytes memory queryMessage = abi.encode(
            QueryParams.BridgedParams({
                storageContract: storageContract,
                params: params,
                startBlock: startBlock,
                endBlock: endBlock,
                blockHash: blockHash,
                proofBlock: proofBlock
            })
        );

        bool forceUpdateGlobalExitRoot = false;

        polygonZkEVMBridge.bridgeMessage(
            destinationNetwork,
            lpnRegistryAddress,
            forceUpdateGlobalExitRoot,
            queryMessage
        );

        emit BridgedQuery(queryMessage);
    }

    /// @notice The relayer withdraws all fees accumulated
    // function withdrawFees() external onlyOwner returns (bool) {
    //     (bool sent,) = msg.sender.call{value: address(this).balance}("");
    //     return sent;
    // }

    function gasFee() public pure returns (uint256) {
        return CDK_GAS_FEE;
    }
}
