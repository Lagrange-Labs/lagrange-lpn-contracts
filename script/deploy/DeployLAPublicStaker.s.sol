// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DeploymentUtils} from "../../src/utils/DeploymentUtils.sol";
import {LAPublicStaker} from "../../src/latoken/LAPublicStaker.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Script to deploy the LAPublicStaker contract
/// @dev Deploys LAPublicStaker with a proxy and initializes it with configuration from environment variables
contract DeployLAPublicStaker is DeploymentUtils {
    /// @notice Deploys the LAPublicStaker contract
    function run() external {
        console.log(unicode"🚀 Deploying LA Public Staker");

        vm.startBroadcast();

        // Get the LA token address from environment variable
        address laToken = vm.envAddress("LA_TOKEN_ADDRESS");
        if (laToken == address(0)) {
            revert(
                "LA_TOKEN_ADDRESS environment variable not set or is zero address"
            );
        }

        // Get configuration from environment variables
        uint16 apyPPT = SafeCast.toUint16(vm.envUint("APY_PPT"));
        uint16 lockupPeriodDays =
            SafeCast.toUint16(vm.envUint("LOCKUP_PERIOD_DAYS"));
        uint96 stakeCap = SafeCast.toUint96(vm.envUint("STAKE_CAP"));
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        // Create configuration
        LAPublicStaker.Config memory config = LAPublicStaker.Config({
            apyPPT: apyPPT,
            lockupPeriodDays: lockupPeriodDays,
            stakeCap: stakeCap
        });

        // Deploy LAPublicStaker implementation
        LAPublicStaker stakerImpl = new LAPublicStaker(laToken, treasury);
        address stakerImplAddr = address(stakerImpl);

        // Deploy proxy and initialize LAPublicStaker
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            stakerImplAddr,
            treasury,
            abi.encodeWithSelector(
                LAPublicStaker.initialize.selector, treasury, config
            )
        );
        address stakerProxy = address(proxy);

        vm.stopBroadcast();

        console.log(unicode"✅ LA Public Staker deployed successfully");
        console.log("Staker Proxy: %s", stakerProxy);
        console.log("Staker Implementation: %s", stakerImplAddr);
        console.log("LA Token: %s", laToken);
        console.log("Treasury: %s", treasury);
        console.log("APY PPT: %d", apyPPT);
        console.log("Lockup Period Days: %d", lockupPeriodDays);
        console.log("Stake Cap: %d", stakeCap);
    }
}
