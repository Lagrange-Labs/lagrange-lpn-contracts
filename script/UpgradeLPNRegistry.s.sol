// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {ChainConnections} from "../src/utils/ChainConnections.sol";
import {Environments} from "../src/utils/Environments.sol";
import {LPNRegistryV1} from "../src/v1/LPNRegistryV1.sol";
import {DeployLPNRegistryV1} from "./deploy/DeployLPNRegistryV1.s.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {isMainnet} from "../src/utils/Constants.sol";
import {ReferenceJSON} from "../src/utils/ReferenceJSON.sol";
import {console} from "forge-std/console.sol";

/// @notice Script to upgrade the LPNRegistry on all chains for a given environment (ex dev-0, test, or prod)
/// @dev This script *doed not* deploy new LPNRegistry contracts, it only upgrades existing ones
contract UpgradeLPNRegistry is
    Script,
    ChainConnections,
    Environments,
    ReferenceJSON
{
    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    constructor() {
        vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    }

    /// @notice Main entrypoint: Upgrades the LPNRegistry on all chains for the given environment
    /// @param env The environment name to upgrade
    function run(string calldata env) external onlyDevOrTest(env) {
        copyVerifier(env);
        string[] memory chains = getChainsForEnv(env);
        for (uint256 i = 0; i < chains.length; i++) {
            upgradeChain(env, chains[i]);
        }
    }

    /// @notice Upgrades the LPNRegistry on a specific env/chain
    /// @param env The environment to upgrade with
    /// @param chain The chain to upgrade
    function upgradeChain(string memory env, string memory chain) public {
        vm.createSelectFork(chain);

        address implAddress = getLPNRegistryImplAddress(env, chain);
        address proxyAddress = getLPNRegistryProxyAddress(env, chain);

        if (proxyAddress == address(0)) {
            console.log(
                unicode"✓ %s: LPNRegistry not deployed on chain, skipping",
                chain
            );
            return;
        }

        // Skip update if the contract is already up to date
        bytes32 existingBytecodeHash = keccak256(implAddress.code);
        bytes32 newBytecodeHash =
            keccak256(vm.getDeployedCode("LPNRegistryV1.sol:LPNRegistryV1"));
        if (existingBytecodeHash == newBytecodeHash) {
            console.log(
                unicode"✓ %s: LPNRegistry already up to date on chain, skipping",
                chain
            );
            return;
        }

        vm.startBroadcast();
        address newImplementation = address(new LPNRegistryV1());
        proxyFactory.upgrade(proxyAddress, newImplementation);
        vm.stopBroadcast();

        console.log(
            unicode"✓ %s: New LPNRegistry deployed with address %s",
            chain,
            newImplementation
        );

        updateLPNRegistryImplAddress(env, chain, newImplementation);
    }

    /// @notice Runs the copy-verifier script
    /// @param env The environment to run the script with
    function copyVerifier(string memory env) public {
        string[] memory inputs = new string[](2);
        inputs[0] =
            string.concat(vm.projectRoot(), "/script/util/copy-verifier.sh");
        inputs[1] = env;
        vm.ffi(inputs);
    }
}
