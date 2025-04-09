// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {LagrangeQueryRouter} from "../v2/LagrangeQueryRouter.sol";
import {ChainConnections} from "./ChainConnections.sol";
import {LATokenMintable} from "../latoken/LATokenMintable.sol";

/// @notice This contract contains many utility functions for deployment scripts
abstract contract DeploymentUtils is ChainConnections, Script {
    address private deployerAddress;

    mapping(string env => string[] chains) private chainsByEnv;

    mapping(uint256 chainId => address addr) private engMultiSigs;
    mapping(uint256 chainId => address addr) private financeMultiSigs;

    mapping(
        string env => mapping(uint256 chainId => LagrangeQueryRouter router)
    ) private routers;

    // la token config
    mapping(uint256 chainId => address addr) private lzEndpoints;
    mapping(uint256 chainId => bool isMintable) private mintableChains;
    mapping(uint256 chainId => address addr) private treasuryAddresses;
    LATokenMintable.Peer[] peers;

    constructor() {
        // Deployer Key
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.addr(deployerKey);
        vm.rememberKey(deployerKey);

        // Environments
        // Dev
        chainsByEnv["dev-0"] = ["holesky"];
        chainsByEnv["dev-1"] = ["holesky"];
        chainsByEnv["dev-3"] = ["holesky"];
        // Test
        chainsByEnv["test"] = [
            // TODO: Add these back in after v2 deployments are complete
            // "base_sepolia",
            // "fraxtal_testnet",
            "holesky"
            // "mantle_sepolia",
            // "scroll_sepolia",
            // "sepolia"
        ];
        // Prod
        chainsByEnv["prod"] =
            ["mainnet", "base", "mantle", "polygon_zkevm", "scroll", "fraxtal"];

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

        // Deployed Router Proxies
        // dev-0
        routers["dev-0"][17000] =
            LagrangeQueryRouter(0x927F5A4570BfA168f0da995CfDbf678d89ADC869);
        // dev-1
        routers["dev-1"][17000] =
            LagrangeQueryRouter(0x62126c172B79a5f2513B3943CceB2da3EfD2Ceec);
        // test
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
        // Holesky
        treasuryAddresses[17000] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;
        // Sepolia
        treasuryAddresses[11155111] = 0x2336Af8d44d7EF6f72E37F28c9D5BB9A926A1cF6;

        // Arbitrum
        addPeer(30110, 0x0000000000000000000000000000000000000000);
        // Base
        addPeer(30184, 0x0000000000000000000000000000000000000000);
        // Optimism
        addPeer(30111, 0x0000000000000000000000000000000000000000);
        // Polygon
        addPeer(30109, 0x0000000000000000000000000000000000000000);
        // BSC
        addPeer(30102, 0x0000000000000000000000000000000000000000);
        // Scroll
        addPeer(30214, 0x0000000000000000000000000000000000000000);
        // Mantle
        addPeer(30181, 0x0000000000000000000000000000000000000000);
        // Gnosis
        addPeer(30145, 0x0000000000000000000000000000000000000000);
        // Polygon-zkevm
        addPeer(30158, 0x0000000000000000000000000000000000000000);
        // Berachain
        addPeer(30362, 0x0000000000000000000000000000000000000000);
    }

    function getDeployerAddress() internal view returns (address) {
        return deployerAddress;
    }

    /// @notice Check if an environment is valid
    function validEnv() private view {
        string memory env = getEnv();
        require(
            keccak256(bytes(env)) == keccak256(bytes("dev-0"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
                || keccak256(bytes(env)) == keccak256(bytes("dev-3"))
                || keccak256(bytes(env)) == keccak256(bytes("test"))
                || keccak256(bytes(env)) == keccak256(bytes("prod")),
            "Invalid environment. Must be 'dev-x', 'test', or 'prod'"
        );
    }

    function getEnv() internal view returns (string memory) {
        return vm.envString("ENV");
    }

    function isDevEnv() internal view returns (bool) {
        string memory env = getEnv();
        return keccak256(bytes(env)) == keccak256(bytes("dev-0"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-3"));
    }

    function isTestEnv() internal view returns (bool) {
        return keccak256(bytes(getEnv())) == keccak256(bytes("test"));
    }

    function isProdEnv() internal view returns (bool) {
        return keccak256(bytes(getEnv())) == keccak256(bytes("prod"));
    }

    /// @notice Get the chains that are configured for a given environment
    /// @return chains the list of chain names that are configured for the given environment
    function getChainsForEnv() internal view returns (string[] memory) {
        return chainsByEnv[getEnv()];
    }

    function getEngMultiSig() internal view returns (address) {
        if (isDevEnv()) return getDeployerAddress();
        address addr = engMultiSigs[block.chainid];
        require(addr != address(0), "Eng multi-sig not found");
        return addr;
    }

    function getFinanceMultiSig() internal view returns (address) {
        if (isDevEnv()) return getDeployerAddress();
        address addr = financeMultiSigs[block.chainid];
        require(addr != address(0), "Finance multi-sig not found");
        return addr;
    }

    function getRouter() internal view returns (LagrangeQueryRouter) {
        LagrangeQueryRouter router = routers[getEnv()][block.chainid];
        require(address(router) != address(0), "Router not found");
        return router;
    }

    function getLzEndpoint() internal view returns (address) {
        address addr = lzEndpoints[block.chainid];
        require(addr != address(0), "LayerZero endpoint not found");
        return addr;
    }

    function addPeer(uint32 endpointID, address peerAddress) internal {
        peers.push(
            LATokenMintable.Peer({
                endpointID: endpointID,
                peerAddress: bytes32(uint256(uint160(peerAddress)))
            })
        );
    }

    function getPeers() internal view returns (LATokenMintable.Peer[] memory) {
        return peers;
    }

    function getTreasuryAddress() internal view returns (address) {
        address addr = treasuryAddresses[block.chainid];
        require(addr != address(0), "Treasury address not found");
        return addr;
    }

    function isMintableChain() internal view returns (bool) {
        return mintableChains[block.chainid];
    }

    /// @notice this function checks that the verifier contracts are up to date, and fails if they are not
    /// @dev sadly we can't fetch the contracts and resume script execution because the compilation step
    /// happens first
    /// @dev running the copy verifier script will produce some ERROR logs - ignore these
    function checkVerifier() internal {
        // compute the md5 hash of the verifier contracts
        string[] memory md5CmdArgs = new string[](2);
        md5CmdArgs[0] = "md5";
        md5CmdArgs[1] = "src/v2/Verifier.sol";

        bytes32 verifierHash = keccak256(vm.ffi(md5CmdArgs));
        md5CmdArgs[1] = "src/v2/Groth16VerifierExtension.sol";
        bytes32 verifierExtensionHash = keccak256(vm.ffi(md5CmdArgs));

        // run the copy verifier script
        string[] memory copyVerifierCmdArgs = new string[](3);
        copyVerifierCmdArgs[0] = "bash";
        copyVerifierCmdArgs[1] = "script/util/copy-verifier.sh";
        copyVerifierCmdArgs[2] = getEnv();
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
