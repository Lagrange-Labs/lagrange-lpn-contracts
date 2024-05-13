// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {
    ETH_MAINNET,
    ETH_SEPOLIA,
    BASE_MAINNET,
    BASE_SEPOLIA,
    FRAXTAL_MAINNET,
    FRAXTAL_HOLESKY,
    isMainnet,
    isTestnet
} from "../src/utils/Constants.sol";
import {stdJson} from "forge-std/stdJson.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

    /// @dev The address of the contract deployer.
    address public deployer;

    // @dev The salt used for deterministic deployment addresses for LPNRegistryV0
    bytes32 public salt =
        isMainnet() ? newSalt("V0_EUCLID_0") : newSalt("V0_EUCLID_4");

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

        print("deployer", deployer);

        if (!vm.exists(outputPath())) {
            initJson();
        }
    }

    // @dev The salt used for deterministic deployment addresses
    function newSalt(string memory discriminator)
        public
        view
        returns (bytes32)
    {
        return bytes32(abi.encodePacked(deployer, discriminator));
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

    function getDeployedStakeRegistry() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.stakeRegistryProxy");
    }

    function getDeployedServiceManager() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.serviceManagerProxy");
    }

    function getAvsDirectory() internal view returns (address) {
        string memory json = vm.readFile(avsConfigPath());
        if (isMainnet()) {
            return json.readAddress(".eigenlayer.mainnet.avsDirectory");
        }

        if (isTestnet()) {
            return json.readAddress(".eigenlayer.holesky.avsDirectory");
        }

        return json.readAddress(".eigenlayer.local.avsDirectory");
    }

    function getDelegationManager() internal view returns (address) {
        string memory json = vm.readFile(avsConfigPath());
        if (isMainnet()) {
            return json.readAddress(".eigenlayer.mainnet.delegationManager");
        }

        if (isTestnet()) {
            return json.readAddress(".eigenlayer.holesky.delegationManager");
        }

        return json.readAddress(".eigenlayer.local.delegationManager");
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

    function avsConfigPath() internal pure returns (string memory) {
        return "./config/avs.json";
    }

    function mkdir(string memory dirPath) internal {
        string[] memory mkdirInputs = new string[](3);
        mkdirInputs[0] = "mkdir";
        mkdirInputs[1] = "-p";
        mkdirInputs[2] = dirPath;
        vm.ffi(mkdirInputs);
    }

    function initJson() private {
        mkdir(outputDir());

        string memory json = "deploymentArtifact";

        string memory addresses = "addresses";
        addresses.serialize("stakeRegistryProxy", address(0));
        addresses.serialize("stakeRegistryImpl", address(0));
        addresses.serialize("serviceManagerProxy", address(0));
        addresses.serialize("serviceManagerImpl", address(0));

        addresses.serialize("storageContract", address(0));
        addresses.serialize("queryClient", address(0));
        addresses.serialize("registryImpl", address(0));
        addresses = addresses.serialize("registryProxy", address(0));

        string memory chainInfo = "chainInfo";
        chainInfo.serialize("chainId", uint256(0));
        chainInfo = chainInfo.serialize("deploymentBlock", uint256(0));

        json.serialize("addresses", addresses);
        json = json.serialize("chainInfo", chainInfo);

        json.write(outputPath());
    }
}
