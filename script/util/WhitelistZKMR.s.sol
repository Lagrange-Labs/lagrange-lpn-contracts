// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {console} from "forge-std/console.sol";
import {
    ETH_MAINNET, ETH_HOLESKY, isMainnet
} from "../../src/utils/Constants.sol";

interface IStakeRegistryZKMR {
    function whitelist(address operator) external view returns (bool);
    function addToWhitelist(address[] calldata operators) external;
}

abstract contract WhitelistBase is BaseScript {
    function checkNetworkRequirement() internal virtual;
    function isOperatorWhitelisted(address operator)
        internal
        virtual
        returns (bool);
    function addOperatorsToWhitelist(address[] memory operators)
        internal
        virtual;

    function run() external isBatch(address(SAFE)) {
        checkNetworkRequirement();

        string memory chainName = getChain(block.chainid).chainAlias;
        string memory root = vm.projectRoot();
        string memory path =
            string.concat(root, "/config/", chainName, "-operators.json");
        string memory json = vm.readFile(path);
        address[] memory operatorsToWhitelist =
            abi.decode(vm.parseJson(json, "."), (address[]));

        // Filter out already whitelisted operators
        uint256 toWhitelistCount = 0;
        address[] memory toWhitelist =
            new address[](operatorsToWhitelist.length);
        for (uint256 i = 0; i < operatorsToWhitelist.length; i++) {
            if (!isOperatorWhitelisted(operatorsToWhitelist[i])) {
                toWhitelist[toWhitelistCount] = operatorsToWhitelist[i];
                toWhitelistCount++;
            }
        }

        // Resize the array to remove empty slots
        assembly {
            mstore(toWhitelist, toWhitelistCount)
        }

        if (toWhitelistCount == 0) {
            console.log("None to whitelist; skipping");
            return;
        }

        console.log("Whitelisting %s operators", toWhitelistCount);
        for (uint256 i = 0; i < toWhitelistCount; i++) {
            console.log(toWhitelist[i]);
        }

        addOperatorsToWhitelist(toWhitelist);
    }
}

contract WhitelistZKMR is WhitelistBase {
    address public immutable ZKMR_STAKE_REGISTRY_ADDRESS = isMainnet()
        ? 0x8dcdCc50Cc00Fe898b037bF61cCf3bf9ba46f15C
        : 0xf724cDC7C40fd6B59590C624E8F0E5E3843b4BE4;

    function checkNetworkRequirement() internal view override {
        require(
            block.chainid == ETH_MAINNET || block.chainid == ETH_HOLESKY,
            "The ZKMR AVS is only deployed on holesky and mainnet"
        );
    }

    function isOperatorWhitelisted(address operator)
        internal
        view
        override
        returns (bool)
    {
        return
            IStakeRegistryZKMR(ZKMR_STAKE_REGISTRY_ADDRESS).whitelist(operator);
    }

    function addOperatorsToWhitelist(address[] memory operators)
        internal
        override
    {
        if (isMainnet()) {
            bytes memory txn = abi.encodeWithSelector(
                IStakeRegistryZKMR.addToWhitelist.selector, operators
            );
            addToBatch(ZKMR_STAKE_REGISTRY_ADDRESS, 0, txn);
            executeBatch(true);
        } else {
            vm.startBroadcast();
            IStakeRegistryZKMR(ZKMR_STAKE_REGISTRY_ADDRESS).addToWhitelist(
                operators
            );
            vm.stopBroadcast();
        }
    }
}
