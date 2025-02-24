// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Deployer} from "../../../src/v2/Deployer.sol";
import {QueryExecutor} from "../../../src/v2/QueryExecutor.sol";
import {QueryExecutorTestHelper} from "./QueryExecutorTestHelper.sol";

/// @title DeployerTestHelper
/// @notice A test helper contract that deploys QueryExecutorTestHelper instead of QueryExecutor
/// @dev XXX testing purposes only XXX
contract DeployerTestHelper is Deployer {
    constructor(address engMultisig, address financeMultisig)
        Deployer(engMultisig, financeMultisig)
    {
        if (block.chainid != 31337) {
            revert("DeployerTestHelper is only intended for use in tests");
        }
    }

    /// @notice Overrides deployQueryExecutor to deploy QueryExecutorTestHelper instead
    /// @param engMultisig The engineering multisig address that will own the contract
    /// @param routerProxy The address of the router proxy contract
    /// @param dbManagerProxy The address of the database manager proxy contract
    /// @param feeCollector The address of the fee collector contract
    /// @return QueryExecutor A new QueryExecutorTestHelper instance cast as QueryExecutor
    function deployQueryExecutor(
        address engMultisig,
        address routerProxy,
        address dbManagerProxy,
        address payable feeCollector,
        QueryExecutor.FeeParams memory feeParams
    ) internal override returns (QueryExecutor) {
        return new QueryExecutorTestHelper(
            engMultisig, routerProxy, dbManagerProxy, feeCollector, feeParams
        );
    }
}
