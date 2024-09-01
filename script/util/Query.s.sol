// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNQueryV0} from "../../src/v0/client/LPNQueryV0.sol";
import {LPNRegistryV0} from "../../src/v0/LPNRegistryV0.sol";
import {isEthereum, isMainnet} from "../../src/utils/Constants.sol";
import {L1BlockNumber} from "../../src/utils/L1Block.sol";

contract Query is BaseScript {
    LPNRegistryV0 registry;
    LPNQueryV0 queryClient;

    address constant BLUR = 0x29469395eAf6f95920E59F858042f0e28D98a20B;
    address constant STAKED_SEALS = 0x1C70D0A86475CC707b48aA79F112857e7957274f;
    address constant ANDRUS = 0xcd82FC81790A8Cf5081F026D2219c91be5a497b5;

    enum QueryType {
        ERC721,
        ERC20Total,
        ERC20Avg
    }

    function run() external broadcaster {
        // QueryType queryType = QueryType.ERC20Avg;
        // QueryType queryType = QueryType.ERC20Total;
        QueryType queryType = QueryType.ERC721;

        registry = LPNRegistryV0(getDeployedRegistry());
        queryClient = LPNQueryV0(getDeployedQueryClient());

        query(queryType);
    }

    function query(QueryType queryType) private {
        uint256 queryRange = 1;
        uint256 endBlock = L1BlockNumber();
        uint256 startBlock = endBlock - (queryRange - 1);

        address holder = deployer;
        string memory contractType;

        uint8 offset;
        uint8 rewardsRate;

        if (queryType == QueryType.ERC721) {
            if (isMainnet()) {
                // holder = BLUR;
                holder = STAKED_SEALS;
            }

            contractType = "erc721Enumerable";
            offset = 5;
        } else if (queryType == QueryType.ERC20Total) {
            if (isMainnet()) {
                holder = 0xfBCA378AeA93EADD6882299A3d74D8641Cc0C4BC;
            } else {
                holder = ANDRUS;
            }

            contractType = "erc20ProportionateBalance";
            rewardsRate = 100;
        } else {
            if (isMainnet()) {
                revert("Not deployed yet");
            }
            contractType = "erc20AvgBalance";
            rewardsRate = 1;
        }

        address storageContract = getDeployedStorageContract(contractType);

        if (!isEthereum()) {
            storageContract = isMainnet()
                ? getDeployedStorageContract(contractType, "mainnet")
                : getDeployedStorageContract(contractType, "holesky");
        }

        if (queryType == QueryType.ERC721) {
            queryClient.queryNFT{value: registry.gasFee()}(
                storageContract, holder, startBlock, endBlock, offset
            );
        } else {
            queryClient.queryERC20{value: registry.gasFee()}(
                storageContract, holder, startBlock, endBlock, rewardsRate
            );
        }
    }
}
