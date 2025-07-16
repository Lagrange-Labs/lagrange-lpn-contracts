// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DeploymentUtils} from "../../src/utils/DeploymentUtils.sol";
import {LAEscrow} from "../../src/latoken/LAEscrow.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Script to deploy the LAEscrow contract
/// @dev Deploys LAEscrow with a proxy and initializes it with configuration from environment variables
contract DeployLAEscrow is DeploymentUtils {
    /// @notice Deploys the LAEscrow contract
    function run() external {
        console.log(unicode"🚀 Deploying LA Escrow");

        vm.startBroadcast();

        // Get the LA token address from environment variable
        address laToken = vm.envAddress("LA_TOKEN_ADDRESS");
        if (laToken == address(0)) {
            revert(
                "LA_TOKEN_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get treasury address from environment variable
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        if (treasury == address(0)) {
            revert(
                "TREASURY_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get initial owner address from environment variable
        address initialOwner = vm.envAddress("INITIAL_OWNER_ADDRESS");
        if (initialOwner == address(0)) {
            revert(
                "INITIAL_OWNER_ADDRESS environment variable not set or is zero address"
            );
        }

        // Deploy LAEscrow implementation
        LAEscrow escrowImpl = new LAEscrow(laToken, treasury);
        address escrowImplAddr = address(escrowImpl);

        // Deploy proxy and initialize LAEscrow
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            escrowImplAddr,
            initialOwner, // admin
            abi.encodeWithSelector(LAEscrow.initialize.selector, initialOwner)
        );
        address escrowProxy = address(proxy);

        vm.stopBroadcast();

        console.log(unicode"✅ LA Escrow deployed successfully");
        console.log("Escrow Proxy: %s", escrowProxy);
        console.log("Escrow Implementation: %s", escrowImplAddr);
        console.log("LA Token: %s", laToken);
        console.log("Treasury: %s", treasury);
        console.log("Initial Owner: %s", initialOwner);
    }
}
