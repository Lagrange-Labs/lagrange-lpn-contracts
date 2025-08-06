// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DeploymentUtils} from "../utils/DeploymentUtils.sol";
import {DeepProvePayments} from "../../src/latoken/DeepProvePayments.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Script to deploy the DeepProvePayments contract
/// @dev Deploys DeepProvePayments with a proxy and initializes it with configuration from environment variables
contract DeployDeepProvePayments is DeploymentUtils {
    /// @notice Deploys the DeepProvePayments contract
    function run() external {
        console.log(unicode"🚀 Deploying Deep Prove Payments");

        vm.startBroadcast();

        // Get the LA token address from environment variable
        address laToken = vm.envAddress("LA_TOKEN_ADDRESS");
        if (laToken == address(0)) {
            revert(
                "LA_TOKEN_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get guarantor address from environment variable
        address guarantor = vm.envAddress("GUARANTOR_ADDRESS");
        if (guarantor == address(0)) {
            revert(
                "GUARANTOR_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get initial owner address from environment variable
        address initialOwner = vm.envAddress("INITIAL_OWNER_ADDRESS");
        if (initialOwner == address(0)) {
            revert(
                "INITIAL_OWNER_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get fee collector address from environment variable
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");
        if (feeCollector == address(0)) {
            revert(
                "FEE_COLLECTOR_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get biller address from environment variable
        address biller = vm.envAddress("BILLER_ADDRESS");
        if (biller == address(0)) {
            revert(
                "BILLER_ADDRESS environment variable not set or is zero address"
            );
        }

        // Deploy DeepProvePayments implementation
        DeepProvePayments escrowImpl =
            new DeepProvePayments(laToken, guarantor, feeCollector);
        address escrowImplAddr = address(escrowImpl);

        // Deploy proxy and initialize DeepProvePayments
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            escrowImplAddr,
            initialOwner, // admin
            abi.encodeWithSelector(
                DeepProvePayments.initialize.selector, initialOwner, biller
            )
        );
        address escrowProxy = address(proxy);

        vm.stopBroadcast();

        console.log(unicode"✅ Deep Prove Payments deployed successfully");
        console.log("Escrow Proxy: %s", escrowProxy);
        console.log("Escrow Implementation: %s", escrowImplAddr);
        console.log("LA Token: %s", laToken);
        console.log("Guarantor: %s", guarantor);
        console.log("Initial Owner: %s", initialOwner);
        console.log("Fee Collector: %s", feeCollector);
        console.log("Biller: %s", biller);
    }
}
