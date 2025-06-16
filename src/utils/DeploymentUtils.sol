// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {LagrangeQueryRouter} from "../v2/LagrangeQueryRouter.sol";
import {ChainConnections} from "./ChainConnections.sol";

/// @notice This contract contains many utility functions for deployment scripts
abstract contract DeploymentUtils is ChainConnections, Script {
    address private deployerAddress;

    string private env;
    mapping(string env => string[] chains) private chainsByEnv;

    mapping(uint256 chainId => string name) private chainNames;
    mapping(uint256 chainId => address addr) private engMultiSigs;
    mapping(uint256 chainId => address addr) private financeMultiSigs;

    mapping(
        string env => mapping(uint256 chainId => LagrangeQueryRouter router)
    ) private routers;

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
        env = vm.envString("ENV");
        _validateEnv();
        // Dev
        chainsByEnv["dev-0"] = ["holesky"];
        chainsByEnv["dev-1"] = ["hoodi"];
        chainsByEnv["dev-3"] = ["hoodi"];
        // Test
        chainsByEnv["test"] = ["hoodi"];
        // Prod
        chainsByEnv["prod"] = ["mainnet"];

        // Multi-sigs
        // Mainnet
        engMultiSigs[1] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[1] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Base
        engMultiSigs[8453] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[8453] = 0x0000000000000000000000000000000000000000; // not yet setup
        // Mantle
        engMultiSigs[5000] = 0xE7cdA508FEB53713fB7C69bb891530C924980366;
        financeMultiSigs[5000] = 0x0000000000000000000000000000000000000000; // not yet setup
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
        // test
        routers["test"][560048] =
            LagrangeQueryRouter(0xA71e8FEEef90BAD0261f840Cc82b3A21CF5a028E);
    }

    function getChainName() internal view returns (string memory) {
        return chainNames[block.chainid];
    }

    function getDeployerAddress() internal view returns (address) {
        return deployerAddress;
    }

    /// @notice Check if an environment is valid
    function _validateEnv() private view {
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
        return env;
    }

    function isDevEnv() internal view returns (bool) {
        return keccak256(bytes(env)) == keccak256(bytes("dev-0"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-1"))
            || keccak256(bytes(env)) == keccak256(bytes("dev-3"));
    }

    function isTestEnv() internal view returns (bool) {
        return keccak256(bytes(env)) == keccak256(bytes("test"));
    }

    function isProdEnv() internal view returns (bool) {
        return keccak256(bytes(env)) == keccak256(bytes("prod"));
    }

    /// @notice Get the chains that are configured for a given environment
    /// @return chains the list of chain names that are configured for the given environment
    function getChainsForEnv() internal view returns (string[] memory) {
        return chainsByEnv[env];
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
        LagrangeQueryRouter router = routers[env][block.chainid];
        require(address(router) != address(0), "Router not found");
        return router;
    }

    /// @notice this function checks that the verifier contracts are up to date, and fails if they are not
    /// @dev sadly we can't fetch the contracts and resume script execution because the compilation step
    /// happens first
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

    function stringConcat(string memory a, string memory b)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(a, b));
    }

    function stringConcat(string memory a, string memory b, string memory c)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(a, b, c));
    }

    function stringConcat(
        string memory a,
        string memory b,
        string memory c,
        string memory d
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }
}
