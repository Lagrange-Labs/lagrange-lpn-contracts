// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {
    ETH_MAINNET,
    ETH_SEPOLIA,
    BASE_MAINNET,
    BASE_SEPOLIA
} from "../src/utils/Constants.sol";
import {stdJson} from "forge-std/stdJson.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

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

    function getDeployedRegistry() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.registryProxy");
    }

    function print(string memory key, string memory value) internal pure {
        console2.log(string(abi.encodePacked(key, "@", value)));
    }

    function print(string memory contractName, address contractAddress)
        internal
        pure
    {
        print(contractName, vm.toString(contractAddress));
    }

    function outputDir() internal returns (string memory) {
        string memory chainName = getChain(block.chainid).chainAlias;
        return string.concat("./script/output/", chainName);
    }

    function outputPath() internal returns (string memory) {
        return string.concat(outputDir(), "/deployment.json");
    }

    function mkdir(string memory dirPath) internal {
        string[] memory mkdirInputs = new string[](3);
        mkdirInputs[0] = "mkdir";
        mkdirInputs[1] = "-p";
        mkdirInputs[2] = dirPath;
        vm.ffi(mkdirInputs);
    }
}
