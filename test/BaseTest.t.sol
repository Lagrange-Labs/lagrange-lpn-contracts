// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
} from "../src/utils/Constants.sol";

abstract contract BaseTest is Test {
    /// @notice The nonce for generating pseudo-random values
    uint256 private nonce;

    /// @notice Generates a random bytes32 value using an incrementing nonce
    /// @dev Hashes the nonce value and increments it to ensure different values on each call
    function randomBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked(++nonce));
    }

    /// @notice Generates a random bytes array of a given length
    function randomBytes(uint256 length) internal returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = randomBytes32()[0];
        }
        return result;
    }

    /// @notice Asserts that a value is present in a list
    function assertContains(address[] memory list, address value)
        internal
        pure
    {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == value) {
                return;
            }
        }
        revert("Address not found in list");
    }

    /// @notice Asserts that a value is *not* present in a list
    function assertDoesNotContain(address[] memory list, address value)
        internal
        pure
    {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == value) {
                revert("Address found in list");
            }
        }
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

    /// @notice Creates a labeled address with non-empty bytecode for use as a contract mock
    function makeMock(string memory name) internal returns (address) {
        address mock = makeAddr(name);
        vm.etch(mock, hex"00");
        return mock;
    }

    /// @dev this is a brute-force implementation of isOPStack, and intentionally different from the one in Constants.sol.
    /// We need this in tests because OP_STACK_L1_BLOCK_PREDEPLOY_ADDR doesn't exist on the test chain
    function _isOPStack(uint256 chainId) private pure returns (bool) {
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
