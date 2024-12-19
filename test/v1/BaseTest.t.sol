// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Importing Test library and constants for chain management
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

// Abstract contract for base testing functionality
abstract contract BaseTest is Test {
    // Nonce for generating random values
    uint256 private nonce;

    /// @notice Generates a random bytes32 value using an incrementing nonce
    /// @dev Hashes the incremented nonce to ensure different values on each call
    /// @return A random bytes32 value
    function randomBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked(++nonce));
    }

    /// @notice Imitates a blockchain environment by setting the chainID 
    ///         and deploying arbitrary bytecode to specific predeploys
    /// @param chainId The ID of the chain to imitate
    /// @dev Reverts if the chain is not supported
    function imitateChain(uint256 chainId) internal {
        // Validate that the chainID is supported
        if (!isLocal() && !isTestnet() && !isMainnet()) {
            revert("Chain not supported");
        }

        // Reset previous imitations
        vm.etch(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR, hex"");

        // Set the chain ID to the specified value
        vm.chainId(chainId);

        // If the chain is part of the OP Stack, deploy specific bytecode
        if (_isOPStack(chainId)) {
            vm.etch(OP_STACK_L1_BLOCK_PREDEPLOY_ADDR, hex"00");
        }
    }

    /// @dev A private function to determine if the provided chainId is part of the OP Stack
    /// @param chainId The ID of the chain to check
    /// @return True if the chainId is part of the OP Stack, false otherwise
    function _isOPStack(uint256 chainId) private pure returns (bool) {
        // Array of supported OP Stack chain IDs
        uint256[6] memory OPChains = [
            BASE_MAINNET,
            BASE_SEPOLIA,
            FRAXTAL_MAINNET,
            FRAXTAL_HOLESKY,
            MANTLE_MAINNET,
            MANTLE_SEPOLIA
        ];

        // Check if the provided chainId exists in the OPChains array
        for (uint256 i = 0; i < OPChains.length; i++) {
            if (OPChains[i] == chainId) return true;
        }
        return false;
    }
}
