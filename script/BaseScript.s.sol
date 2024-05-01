// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {
    ETH_MAINNET,
    ETH_SEPOLIA,
    BASE_MAINNET,
    BASE_SEPOLIA,
    isMainnet
} from "../src/utils/Constants.sol";
import {stdJson} from "forge-std/stdJson.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

    /// @dev The address of the contract deployer.
    address public deployer;

    // @dev The salt used for deterministic deployment addresses with CREATE2
    bytes32 public salt;

    modifier broadcaster() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    constructor() {
        // (, deployer,) = vm.readCallers(); // TODO: read sender from env
        if (isMainnet()) {
            deployer = getDeployerAddress();
        } else {
            deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        }

        if (block.chainid == ETH_MAINNET) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_0"));
        } else if (block.chainid == BASE_MAINNET) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_0"));
        } else if (block.chainid == ETH_SEPOLIA) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_4"));
        } else if (block.chainid == BASE_SEPOLIA) {
            salt = bytes32(abi.encodePacked(deployer, "V0_EUCLID_4"));
        }
    }

    function setDeployer(address _deployer) public {
        deployer = _deployer;
    }

    function getDeployerAddress() internal view returns (address) {
        return vm.envAddress("DEPLOYER_ADDR");
    }

    function getDeployedRegistry() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.registryProxy");
    }

    function getDeployedStorageContract() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.storageContract");
    }

    function getDeployedStorageContract(string memory chainName)
        internal
        view
        returns (address)
    {
        string memory json = vm.readFile(outputPath(chainName));
        return json.readAddress(".addresses.storageContract");
    }

    function getDeployedQueryClient() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.queryClient");
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
        setChain(
            "base_sepolia",
            Chain(
                "Base Sepolia",
                84532,
                "base_sepolia",
                "https://sepolia.base.org"
            )
        );

        string memory chainName = getChain(block.chainid).chainAlias;
        return outputDir(chainName);
    }

    function outputDir(string memory chainName)
        internal
        pure
        returns (string memory)
    {
        return string.concat("./script/output/", chainName);
    }

    function outputPath() internal returns (string memory) {
        return string.concat(outputDir(), "/deployment.json");
    }

    function outputPath(string memory chainName)
        internal
        pure
        returns (string memory)
    {
        return string.concat(outputDir(chainName), "/deployment.json");
    }

    function mkdir(string memory dirPath) internal {
        string[] memory mkdirInputs = new string[](3);
        mkdirInputs[0] = "mkdir";
        mkdirInputs[1] = "-p";
        mkdirInputs[2] = dirPath;
        vm.ffi(mkdirInputs);
    }
}
