// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Vm} from "forge-std/Vm.sol";
import {ProxyAdmin} from
    "@openzeppelin-contracts-5.2.0/proxy/transparent/ProxyAdmin.sol";

// EIP-1967 implementation slot
bytes32 constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

// EIP-1967 admin slot
bytes32 constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

// Initialized slot for OpenZeppelin's Initializable
bytes32 constant INITIALIZED_SLOT =
    0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

// Get the VM instance (has to be constant to be used in a file-level function declaration)
Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

/// Gets the implementation address of a transparent proxy
/// @param proxyAddress The address of the proxy contract
/// @return The implementation address
/// @dev this function only works in scripts & tests because it uses the vm cheat code
function getProxyImplementation(address proxyAddress) view returns (address) {
    bytes32 implSlot = vm.load(proxyAddress, IMPLEMENTATION_SLOT);
    return address(uint160(uint256(implSlot)));
}

/// Gets the admin address of a transparent proxy
/// @param proxyAddress The address of the proxy contract
/// @return The admin address
/// @dev this function only works in scripts & tests because it uses the vm cheat code
function getProxyAdmin(address proxyAddress) view returns (address) {
    bytes32 adminSlot = vm.load(proxyAddress, ADMIN_SLOT);
    return address(uint160(uint256(adminSlot)));
}

/// @notice Gets the owner of the proxy admin contract
/// @param proxy The address of the proxy contract
/// @return owner The owner of the proxy admin contract
/// @dev this is the account that can upgrade the proxy
function getProxyAdminOwner(address proxy) view returns (address) {
    return ProxyAdmin(getProxyAdmin(proxy)).owner();
}

/// Checks if a proxy contract has been initialized
/// @param proxyAddress The address of the proxy contract
/// @return True if the contract is initialized, false otherwise
/// @dev this function only works in scripts & tests because it uses the vm cheat code
function isInitialized(address proxyAddress) view returns (bool) {
    bytes32 value = vm.load(proxyAddress, INITIALIZED_SLOT);
    return uint256(value) == 1;
}
