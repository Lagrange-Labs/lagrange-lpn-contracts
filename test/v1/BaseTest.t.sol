// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    isLocal,
    isTestnet,
    isMainnet,
    isOPStack,
    OP_STACK_L1_BLOCK_PREDEPLOY_ADDR,
    BASE_MAINNET,
    BASE_SEPOLIA,
    FRAXTAL_MAINNET,
    FRAXTAL_HOLESKY,
    MANTLE_MAINNET,
    MANTLE_SEPOLIA
} from "../../src/utils/Constants.sol";

abstract contract BaseTest is Test {
    uint256 private nonce;

    /// @notice Generates a random bytes32 value using an incrementing nonce
    /// @dev Hashes the nonce value and increments it to ensure different values on each call
    function randomBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked(++nonce));
    }

    /// @notice Imitates a chain by setting the chainID and deploying arbitrary bytecode to certain predeploys
    function imitateChain(uint256 chainId) internal {
        // validate the chainID is supported
        if (!isLocal() && !isTestnet() && !isMainnet()) {
            revert("Chain not supported");
        }
        // reset previouse imitations
        vm.etch(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR, hex"");
        // imitate chain
        vm.chainId(chainId);

        if (_isOPStack(chainId)) {
            vm.etch(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR, hex"00");
        }
    }

    /// @dev this is a brute-force implementation of isOPStack, and intentionally different from the one in Constants.sol.
    /// We need this in tests because OP_STACK_L1_BLOCK_PREDEPLOY_ADDR doesn't exist on the test chain
    function _isOPStack(uint256 chainId) private view returns (bool) {
        uint256[6] memory OPChains = [
            BASE_MAINNET,
            BASE_SEPOLIA,
            FRAXTAL_MAINNET,
            FRAXTAL_HOLESKY,
            MANTLE_MAINNET,
            MANTLE_SEPOLIA
        ];
        for (uint256 i = 0; i < OPChains.length; i++) {
            if (OPChains[i] == chainId) return true;
        }
        return false;
    }
}
