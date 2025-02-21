// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LagrangeQueryRouter} from "./LagrangeQueryRouter.sol";
import {QueryExecutor} from "./QueryExecutor.sol";
import {QueryExecutorTestHelper} from
    "../../test/v2/test_helpers/QueryExecutorTestHelper.sol";
import {DatabaseManager} from "./DatabaseManager.sol";
import {FeeCollector} from "./FeeCollector.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Deployer
/// @notice Deploys and configures the Lagrange protocol contracts then self-destructs
/// @dev This is a one-time use contract that sets up the initial protocol deployment
/// @dev This contract simplifies protocol deployment to a single transaction, rather
/// than a multi-step process with multiple transactions
contract Deployer {
    event ContractsDeployed(
        address routerProxy,
        address dbManagerProxy,
        address feeCollector,
        address queryExecutor
    );

    /// @notice Deploys and configures the Lagrange protocol contracts, then self-destructs
    /// @param engMultisig The engineering multisig address
    /// @param financeMultisig The finance multisig address
    constructor(address engMultisig, address financeMultisig) {
        // Deploy implementations
        LagrangeQueryRouter routerImpl = new LagrangeQueryRouter();
        DatabaseManager dbManagerImpl = new DatabaseManager();

        // Deploy RouterProxy, but do not initialize it yet
        TransparentUpgradeableProxy routerProxy = new TransparentUpgradeableProxy(
            address(routerImpl), engMultisig, ""
        );

        // Deploy and initialize DatabaseManagerProxy
        TransparentUpgradeableProxy dbManagerProxy = new TransparentUpgradeableProxy(
            address(dbManagerImpl),
            engMultisig,
            abi.encodeWithSelector(
                DatabaseManager.initialize.selector, engMultisig
            )
        );

        // Deploy FeeCollector
        FeeCollector feeCollector = new FeeCollector(financeMultisig);

        // Deploy QueryExecutor
        QueryExecutor queryExecutor = deployQueryExecutor(
            engMultisig,
            address(routerProxy),
            address(dbManagerProxy),
            payable(address(feeCollector))
        );

        // Initialize Router, sets default queryExecutor
        LagrangeQueryRouter(address(routerProxy)).initialize(
            engMultisig, queryExecutor
        );

        emit ContractsDeployed(
            address(routerProxy),
            address(dbManagerProxy),
            address(feeCollector),
            address(queryExecutor)
        );

        // Self destruct
        selfdestruct(payable(msg.sender));
    }

    /// @notice Deploys new QueryExecutor contract
    /// @param engMultisig The engineering multisig address that will own the contract
    /// @param routerProxy The address of the router proxy contract
    /// @param dbManagerProxy The address of the database manager proxy contract
    /// @param feeCollector The address of the fee collector contract
    /// @return QueryExecutor A new QueryExecutor instance
    /// @dev this is separated into it's own function so that it can be overridden for testing
    function deployQueryExecutor(
        address engMultisig,
        address routerProxy,
        address dbManagerProxy,
        address payable feeCollector
    ) internal virtual returns (QueryExecutor) {
        return new QueryExecutor(
            engMultisig, routerProxy, dbManagerProxy, feeCollector
        );
    }
}
