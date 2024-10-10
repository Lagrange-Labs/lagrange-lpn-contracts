// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {WhitelistBase} from "./WhitelistZKMR.s.sol";
import {ETH_MAINNET, isMainnet} from "../../src/utils/Constants.sol";

interface IStakeRegistryLSC {
    function operatorWhitelist(address operator) external view returns (bool);
    function addOperatorsToWhitelist(address[] calldata operators) external;
}

contract WhitelistLSC is WhitelistBase {
    address public immutable LSC_STAKE_REGISTRY_ADDRESS =
        isMainnet() ? 0x35F4f28A8d3Ff20EEd10e087e8F96Ea2641E6AA2 : address(0);

    function checkNetworkRequirement() internal view override {
        require(
            block.chainid == ETH_MAINNET,
            "The LSC AVS is only managed by the multisig on mainnet"
        );
    }

    function isOperatorWhitelisted(address operator)
        internal
        view
        override
        returns (bool)
    {
        return IStakeRegistryLSC(LSC_STAKE_REGISTRY_ADDRESS).operatorWhitelist(
            operator
        );
    }

    function addOperatorsToWhitelist(address[] memory operators)
        internal
        override
    {
        bytes memory txn = abi.encodeWithSelector(
            IStakeRegistryLSC.addOperatorsToWhitelist.selector, operators
        );
        addToBatch(LSC_STAKE_REGISTRY_ADDRESS, 0, txn);
        executeBatch(true);
    }
}
