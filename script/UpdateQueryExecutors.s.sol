// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {console} from "forge-std/console.sol";
import {DeploymentUtils} from "../src/utils/DeploymentUtils.sol";
import {QueryExecutor} from "../src/v2/QueryExecutor.sol";
import {LagrangeQueryRouter} from "../src/v2/LagrangeQueryRouter.sol";

/// @notice Script to upgrade the QueryExecutor on all chains for a given environment (ex dev-0, test, or prod)
/// @dev This script does two things: deploys a new QueryExecutor contract and updates the defaultQueryExecutor on the Router
/// @dev This scripts assumes that the copy-verifier.sh script has already been run, and that the latest source code is available
contract UpdateQueryExecutors is DeploymentUtils {
    /// @notice Main entrypoint: Upgrades the QueryExecutor on all chains for the given environment
    function run() external {
        checkVerifier();

        string[] memory chains = getChainsForEnv();
        for (uint256 i = 0; i < chains.length; i++) {
            upgradeChain(chains[i]);
        }
    }

    /// @notice Upgrades the LPNRegistry on a specific env/chain
    /// @param chain The chain to upgrade
    function upgradeChain(string memory chain) public {
        vm.createSelectFork(chain);

        LagrangeQueryRouter router = getRouter();
        QueryExecutor oldExecutor =
            QueryExecutor(address(router.getDefaultQueryExecutor()));

        vm.startBroadcast();

        // Deploy new QueryExecutor with config from old executor
        QueryExecutor queryExecutor = new QueryExecutor(
            oldExecutor.owner(),
            address(router),
            oldExecutor.getDBManager(),
            payable(oldExecutor.getFeeCollector()),
            oldExecutor.getConfig()
        );

        if (isDevEnv()) {
            router.setDefaultQueryExecutor(queryExecutor);
        } else {
            console.log(
                unicode"⚠️ Cannot automatically update QueryExecutor on non-dev environment, use mutisig"
            );
        }

        vm.stopBroadcast();

        console.log(
            unicode"✅ QueryExecutor deployed sucessfully on chain %d: %s",
            block.chainid,
            address(queryExecutor)
        );
    }
}
