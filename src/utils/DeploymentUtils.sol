// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {LagrangeQueryRouter} from "../v2/LagrangeQueryRouter.sol";
import {ChainConnections} from "./ChainConnections.sol";
import {LATokenBase} from "../latoken/LATokenBase.sol";

/// @title DeploymentUtils
/// @notice This contract contains many utility functions for deployment scripts
abstract contract DeploymentUtils is ChainConnections, Script {
    struct PeerConfig {
        LATokenBase.Peer peer;
        uint256 chainId;
    }

    address private deployerAddress;

    mapping(string env => string[] chains) private chainsByEnv;

    mapping(uint256 chainId => string name) private chainNames;
    mapping(uint256 chainId => address addr) private engMultiSigs;
    mapping(uint256 chainId => address addr) private financeMultiSigs;

    mapping(
        string env => mapping(uint256 chainId => LagrangeQueryRouter router)
    ) private routers;

    // la token config
    mapping(uint256 chainId => address addr) private lzEndpoints;
    mapping(uint256 chainId => bool isMintable) private mintableChains;
    mapping(uint256 chainId => address addr) private treasuryAddresses;
    PeerConfig[] private peers;

    /// @notice Initializes deployment utilities, loads config from environment, and seeds in-memory mappings
    constructor() {
        // Deployer Key
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.addr(deployerKey);
        vm.rememberKey(deployerKey);

        // Chain Names
        chainNames[31337] = "anvil";
        chainNames[1] = "mainnet";
        chainNames[8453] = "base";
        chainNames[5000] = "mantle";
        chainNames[17000] = "holesky";
        chainNames[11155111] = "sepolia";
        chainNames[2522] = "fraxtal";
        chainNames[534351] = "scroll";
        chainNames[1101] = "polygon_zkevm";
        chainNames[84532] = "base_sepolia";
        chainNames[534351] = "scroll_sepolia";
        chainNames[560048] = "hoodi";

        // Environments
        // Dev
        // chainsByEnv["dev-0"] = ["holesky"];
        chainsByEnv["dev-0"] = ["hoodi", "holesky"];
        chainsByEnv["dev-1"] = ["hoodi", "holesky"];
        chainsByEnv["dev-2"] = ["hoodi"];
        chainsByEnv["dev-3"] = ["hoodi"];
        // Test
        // chainsByEnv["test"] = ["hoodi"];
        chainsByEnv["test"] = ["holesky"];
        // Prod
        chainsByEnv["prod"] = ["mainnet"];

        // Multi-sigs
        // Mainnet
        engMultiSigs[1] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        // Base
        engMultiSigs[8453] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        // Mantle
        engMultiSigs[5000] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        // Holesky
        engMultiSigs[17000] = 0x4584E9d4685E9Ffcc2d2823D016A08BA72Ad555f;
        financeMultiSigs[17000] = 0x4584E9d4685E9Ffcc2d2823D016A08BA72Ad555f;
        // Sepolia
        engMultiSigs[11155111] = 0x28670dAFD8F88f8f4b638E66c01d33A39b614Da6;
        financeMultiSigs[11155111] = 0x28670dAFD8F88f8f4b638E66c01d33A39b614Da6;
        // Fraxtal Testnet
        engMultiSigs[2522] = 0x85AC3c40e4227Af5993FC4dABe46D8D6493989fb;
        financeMultiSigs[2522] = 0x85AC3c40e4227Af5993FC4dABe46D8D6493989fb;
        // Scroll Sepolia
        engMultiSigs[534351] = 0x7fB320649abb0333b309ee876c68a1d2cd722429;
        financeMultiSigs[534351] = 0x7fB320649abb0333b309ee876c68a1d2cd722429;
        // Base Sepolia
        engMultiSigs[84532] = 0x80838Fb7C7E6d06Ff9cCe6139CE83D2Dc2d4d7A9;
        financeMultiSigs[84532] = 0x80838Fb7C7E6d06Ff9cCe6139CE83D2Dc2d4d7A9;
        // Polygon zkEVM
        engMultiSigs[1101] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[1101] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        // Hoodi
        engMultiSigs[560048] = 0xC93e57A48a8052665C57677B3274ACaC67c1eB2E;
        financeMultiSigs[560048] = 0xC93e57A48a8052665C57677B3274ACaC67c1eB2E;

        // Deployed Router Proxies
        // dev-0
        routers["dev-0"][560048] =
            LagrangeQueryRouter(0x43FA1Ccf0ca5977c3D8B6c2b073240f700960c77);
        routers["dev-0"][17000] =
            LagrangeQueryRouter(0x927F5A4570BfA168f0da995CfDbf678d89ADC869);
        // dev-1
        routers["dev-1"][560048] =
            LagrangeQueryRouter(0x90594F0ED032E7adba9CF01607291bE7666d4BE8);
        routers["dev-1"][17000] =
            LagrangeQueryRouter(0x62126c172B79a5f2513B3943CceB2da3EfD2Ceec);
        // dev-2
        routers["dev-2"][560048] =
            LagrangeQueryRouter(0xBEfF00B9C0E73D818d1b476a4dDBDa3229fDf22e);
        // dev-3
        routers["dev-3"][560048] =
            LagrangeQueryRouter(0x0c4B8fCB41548167dea619C4e00B101Efa6784d0);

        // test
        routers["test"][560048] =
            LagrangeQueryRouter(0xA71e8FEEef90BAD0261f840Cc82b3A21CF5a028E);

        routers["test"][17000] =
            LagrangeQueryRouter(0x988732D6aaa4a7419bE3628444Ae02e86FeD41ac);

        // LayerZero Endpoints
        // Anvil
        lzEndpoints[31337] = 0x0000000000000000000000000000000000000999;
        // Mainnet
        lzEndpoints[1] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Holesky
        lzEndpoints[17000] = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        // Sepolia
        lzEndpoints[11155111] = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        // Arbitrum
        lzEndpoints[42161] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Base
        lzEndpoints[8453] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Optimism
        lzEndpoints[10] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Polygon
        lzEndpoints[137] = 0x1a44076050125825900e736c501f859c50fE728c;
        // BSC
        lzEndpoints[56] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Scroll
        lzEndpoints[534352] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Mantle
        lzEndpoints[5000] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Cronos
        lzEndpoints[25] = 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9;
        // Gnosis
        lzEndpoints[100] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Polygon-zkevm
        lzEndpoints[1101] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Berachain
        lzEndpoints[80094] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;

        // Chains with minting
        // Mainnet
        mintableChains[1] = true;
        // Holesky
        mintableChains[17000] = true;
        // Sepolia
        mintableChains[11155111] = true;

        // Treasury addresses
        // Mainnet
        treasuryAddresses[1] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Arbitrum
        treasuryAddresses[42161] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Base
        treasuryAddresses[8453] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Optimism
        treasuryAddresses[10] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Polygon
        treasuryAddresses[137] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // BSC
        treasuryAddresses[56] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Scroll
        treasuryAddresses[534352] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Mantle
        treasuryAddresses[5000] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Gnosis
        treasuryAddresses[100] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Polygon-zkevm
        treasuryAddresses[1101] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Berachain
        treasuryAddresses[80094] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;

        // OFT Peers
        // Mainnet
        addPeer(1, 30101, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // // Arbitrum
        addPeer(42161, 30110, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Base
        addPeer(8453, 30184, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Optimism
        addPeer(10, 30111, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Polygon
        addPeer(137, 30109, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Scroll
        addPeer(534352, 30214, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Gnosis
        addPeer(100, 30145, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Polygon-zkevm
        addPeer(1101, 30158, 0x0fc2a55d5BD13033f1ee0cdd11f60F7eFe66f467);
        // Berachain
        addPeer(80094, 30362, 0x389AD4bb96d0D6EE5B6eF0EFAF4b7db0bA2e02a0);
    }

    /// @notice Returns the human-readable chain name for the current `block.chainid`
    /// @return chainName The chain name associated with the current chain ID
    function getChainName() internal view returns (string memory) {
        return chainNames[block.chainid];
    }

    /// @notice Returns the deployer EOA derived from the `PRIVATE_KEY` environment variable
    /// @return deployer The deployer address used by scripts
    function getDeployerAddress() internal view returns (address) {
        return deployerAddress;
    }

    /// @notice Returns the active deployment environment string from `ENV`
    /// @return env The current environment name (e.g. "dev-0", "test", "prod")
    function getEnv() internal view returns (string memory) {
        return vm.envString("ENV");
    }

    /// @notice Checks whether the current environment is a dev environment
    /// @return isDev True if the environment is one of the supported dev variants
    function isDevEnv() internal view returns (bool) {
        string memory env = getEnv();
        return keccak256(bytes(env)) == keccak256(bytes("dev-0"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-3"));
    }

    /// @notice Checks whether the current environment is the test environment
    /// @return isTest True if `ENV` equals "test"
    function isTestEnv() internal view returns (bool) {
        return keccak256(bytes(getEnv())) == keccak256(bytes("test"));
    }

    /// @notice Checks whether the current environment is the production environment
    /// @return isProd True if `ENV` equals "prod"
    function isProdEnv() internal view returns (bool) {
        return keccak256(bytes(getEnv())) == keccak256(bytes("prod"));
    }

    /// @notice Get the chains that are configured for a given environment
    /// @return chains the list of chain names that are configured for the given environment
    function getChainsForEnv() internal view returns (string[] memory) {
        return chainsByEnv[getEnv()];
    }

    /// @notice Returns the engineering multisig for the current chain, or the deployer in dev envs
    /// @return multisig The engineering multisig address
    function getEngMultiSig() internal view returns (address) {
        if (isDevEnv()) return getDeployerAddress();
        address addr = engMultiSigs[block.chainid];
        require(addr != address(0), "Eng multi-sig not found");
        return addr;
    }

    /// @notice Returns the finance multisig for the current chain, or the deployer in dev envs
    /// @return multisig The finance multisig address
    function getFinanceMultiSig() internal view returns (address) {
        if (isDevEnv()) return getDeployerAddress();
        address addr = financeMultiSigs[block.chainid];
        require(addr != address(0), "Finance multi-sig not found");
        return addr;
    }

    /// @notice Returns the configured `LagrangeQueryRouter` for the current chain and environment
    /// @return router The router proxy address
    function getRouter() internal view returns (LagrangeQueryRouter) {
        LagrangeQueryRouter router = routers[getEnv()][block.chainid];
        require(address(router) != address(0), "Router not found");
        return router;
    }

    /// @notice Returns the LayerZero endpoint for the current chain
    /// @return endpoint The LayerZero endpoint address
    function getLzEndpoint() internal view returns (address) {
        address addr = lzEndpoints[block.chainid];
        require(addr != address(0), "LayerZero endpoint not found");
        return addr;
    }

    /// @notice Adds an OFT peer configuration for a specific chain
    /// @param chainId The EVM chain ID where the peer contract is deployed
    /// @param endpointID The LayerZero endpoint ID for the peer chain
    /// @param peerAddress The peer contract address on the target chain
    function addPeer(uint256 chainId, uint32 endpointID, address peerAddress)
        private
    {
        peers.push(
            PeerConfig({
                chainId: chainId,
                peer: LATokenBase.Peer({
                    endpointID: endpointID,
                    peerAddress: bytes32(uint256(uint160(peerAddress)))
                })
            })
        );
    }

    /// @notice Returns the configured OFT peers for all chains other than the current one
    /// @return peersForOtherChains The array of peer configurations
    function getPeers() internal view returns (LATokenBase.Peer[] memory) {
        LATokenBase.Peer[] memory filteredPeers =
            new LATokenBase.Peer[](peers.length);
        uint256 count = 0;
        for (uint256 i = 0; i < peers.length; ++i) {
            if (peers[i].chainId != block.chainid) {
                filteredPeers[count] = peers[i].peer;
                ++count;
            }
        }
        assembly {
            mstore(filteredPeers, count)
        }
        return filteredPeers;
    }

    /// @notice Returns the treasury address for the current chain
    /// @return treasury The treasury address
    function getTreasuryAddress() internal view returns (address) {
        address addr = treasuryAddresses[block.chainid];
        require(addr != address(0), "Treasury address not found");
        return addr;
    }

    /// @notice Indicates whether minting is enabled on the current chain
    /// @return canMint True if minting is allowed on this chain
    function isMintableChain() internal view returns (bool) {
        return mintableChains[block.chainid];
    }

    /// @notice this function checks that the verifier contracts are up to date, and fails if they are not
    /// @dev sadly we can't fetch the contracts and resume script execution because the compilation step
    /// happens first
    function checkVerifier() internal {
        string memory ppVersion = vm.envString("PP_VERSION");

        // compute the md5 hash of the verifier contracts
        string[] memory md5CmdArgs = new string[](2);
        md5CmdArgs[0] = "md5";
        md5CmdArgs[1] = "src/v2/Verifier.sol";

        bytes32 verifierHash = keccak256(vm.ffi(md5CmdArgs));
        md5CmdArgs[1] = "src/v2/Groth16VerifierExtension.sol";
        bytes32 verifierExtensionHash = keccak256(vm.ffi(md5CmdArgs));

        // run the copy verifier script
        string[] memory copyVerifierCmdArgs = new string[](4);
        copyVerifierCmdArgs[0] = "bash";
        copyVerifierCmdArgs[1] = "script/copy-verifier.sh";
        copyVerifierCmdArgs[2] = getEnv();
        copyVerifierCmdArgs[3] = ppVersion;
        vm.ffi(copyVerifierCmdArgs);

        // compute the md5 hash of the new verifier contracts
        md5CmdArgs[1] = "src/v2/Verifier.sol";
        bytes32 newVerifierHash = keccak256(vm.ffi(md5CmdArgs));
        md5CmdArgs[1] = "src/v2/Groth16VerifierExtension.sol";
        bytes32 newVerifierExtensionHash = keccak256(vm.ffi(md5CmdArgs));

        // check before vs after
        require(
            verifierHash == newVerifierHash
                && verifierExtensionHash == newVerifierExtensionHash,
            "Verifier.sol and/or Groth16VerifierExtension.sol have changed, please re-run deployment script"
        );
    }
}
