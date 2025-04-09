// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeploymentUtils} from "../../src/utils/DeploymentUtils.sol";
import {LATokenMintableDeployer} from
    "../../src/latoken/LATokenMintableDeployer.sol";
import {LATokenDeployer} from "../../src/latoken/LATokenDeployer.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    ETH_MAINNET,
    ETH_HOLESKY,
    ETH_SEPOLIA
} from "../../src/utils/Constants.sol";

/// @notice Script to deploy the Lagrange (LA) token
/// @dev Deploys only the mintable version on Ethereum mainnet, Holesky, and Sepolia
/// @dev Uses LATokenMintableDeployer contract to deploy in a single transaction
contract DeployLAToken is DeploymentUtils {
    uint256 private constant INFLATION_RATE = 400; // 4%
    uint256 private constant INITIAL_SUPPLY = 1_000_000_000 ether;
    address private constant INITIAL_MINT_HANDLER_ADDRESS =
        0x050421c886B6A031ee86033d98F77fb87208472c;

    /// @notice Deploys the Lagrange (LA) token
    function run() external {
        console.log(unicode"🚀 Deploying LA Token (Mintable)");

        vm.startBroadcast();
        vm.recordLogs();

        if (isMintableChain()) {
            // Deploy and configure the LA token using the LATokenMintableDeployer
            new LATokenMintableDeployer(
                INFLATION_RATE,
                INITIAL_SUPPLY,
                getLzEndpoint(),
                INITIAL_MINT_HANDLER_ADDRESS,
                getTreasuryAddress(),
                getPeers()
            );
        } else {
            // Deploy and configure the LA token using the LATokenDeployer
            new LATokenDeployer(
                getTreasuryAddress(), getLzEndpoint(), getPeers()
            );
        }

        // Get the deployed addresses from the emitted event
        vm.stopBroadcast();

        // Get the TokenDeployed event (should be the only event)
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory lastEntry = entries[entries.length - 1];
        require(
            lastEntry.topics[0]
                == LATokenMintableDeployer.TokenDeployed.selector,
            "could not find TokenDeployed event"
        );

        // Parse emitted addresses from event
        (address tokenProxy, address tokenImplementation) =
            abi.decode(lastEntry.data, (address, address));

        console.log(unicode"✅ LA Token deployed successfully");
        console.log("Token Proxy: %s", tokenProxy);
        console.log("Token Implementation: %s", tokenImplementation);

        require(
            IERC20(tokenProxy).balanceOf(INITIAL_MINT_HANDLER_ADDRESS)
                == INITIAL_SUPPLY,
            "Initial mint not successful"
        );
        require(
            IERC20(tokenProxy).totalSupply() == INITIAL_SUPPLY,
            "Initial balance mismatch"
        );
    }
}
