// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {
    ETH_MAINNET,
    ETH_SEPOLIA,
    BASE_MAINNET,
    BASE_SEPOLIA
} from "../src/utils/Constants.sol";

abstract contract BaseScript is Script {
    /// @dev The address of the contract deployer.
    address public deployer;

    // @dev The salt used for deterministic deployment addresses with CREATE2
    bytes32 public salt;

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }

    constructor() {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        if (block.chainid == ETH_MAINNET) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_0"));
        } else if (block.chainid == BASE_MAINNET) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_0"));
        } else if (block.chainid == ETH_SEPOLIA) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_1"));
        } else if (block.chainid == BASE_SEPOLIA) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_0"));
        }
    }

    function setDeployer(address _deployer) public {
        deployer = _deployer;
    }

    function getAddress() internal view returns (address) {
        return vm.envAddress("address");
    }

    function print(string memory contractName, address contractAddress)
        internal
        pure
    {
        console2.log(
            string(
                abi.encodePacked(
                    contractName, "@", vm.toString(address(contractAddress))
                )
            )
        );
    }
}
