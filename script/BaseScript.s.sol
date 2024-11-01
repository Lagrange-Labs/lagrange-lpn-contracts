// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2, StdChains} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {BatchScript} from "forge-safe/BatchScript.sol";
import {ISafe} from "safe-smart-account/interfaces/ISafe.sol";

import {
    MANTLE_MAINNET,
    MANTLE_SEPOLIA,
    isMainnet,
    isTestnet
} from "../src/utils/Constants.sol";

abstract contract BaseScript is BatchScript {
    using stdJson for string;

    enum Version {
        V0,
        V1
    }

    /// @dev The address of Lagrange's Multisig
    ISafe SAFE = ISafe(0xE7cdA508FEB53713fB7C69bb891530C924980366);

    /// @dev The address of the contract deployer.
    address public deployer;

    modifier broadcaster() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    constructor() {
        setChain(
            "mantle",
            ChainData("Mantle", MANTLE_MAINNET, "https://rpc.mantle.xyz")
        );
        setChain(
            "mantle_sepolia",
            ChainData(
                "Mantle Sepolia",
                MANTLE_SEPOLIA,
                "https://rpc.sepolia.mantle.xyz"
            )
        );

        setChain(
            "polygon_zkevm",
            ChainData("Polygon zkEVM", 1101, "https://zkevm-rpc.com")
        );

        if (isMainnet()) {
            vm.startBroadcast();
            (, deployer,) = vm.readCallers();
            vm.stopBroadcast();
        } else {
            deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        }

        print("deployer", deployer);

        if (!vm.exists(outputPath(Version.V1))) {
            initJson(Version.V1);
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

    function getDeployedRegistry() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.registryProxy");
    }

    function getDeployedRegistry(Version version_) internal returns (address) {
        string memory json = vm.readFile(outputPath(version_));
        return json.readAddress(".addresses.registryProxy");
    }

    function getDeployedStorageContract(string memory contractType)
        internal
        returns (address)
    {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(
            string(
                abi.encodePacked(".addresses.storageContracts.", contractType)
            )
        );
    }

    function getDeployedStorageContract(
        string memory contractType,
        string memory chainName
    ) internal view returns (address) {
        string memory json = vm.readFile(outputPath(chainName));
        return json.readAddress(
            string(
                abi.encodePacked(".addresses.storageContracts.", contractType)
            )
        );
    }

    function getDeployedQueryClient() internal returns (address) {
        string memory json = vm.readFile(outputPath());
        return json.readAddress(".addresses.queryClientProxy");
    }

    function getDeployedQueryClient(Version version_)
        internal
        returns (address)
    {
        string memory json = vm.readFile(outputPath(version_));
        return json.readAddress(".addresses.queryClientProxy");
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

    function getChainAlias() internal returns (string memory) {
        string memory envAlias = vm.envString("CHAIN_ALIAS");

        if (bytes(envAlias).length > 0) {
            return envAlias;
        }

        return getChain(block.chainid).chainAlias;
    }

    function outputDir() internal returns (string memory) {
        string memory chainName = getChainAlias();
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
        return outputPath(Version.V1);
    }

    function outputPath(string memory chainName)
        internal
        pure
        returns (string memory)
    {
        return string.concat(outputDir(chainName), "/deployment.json");
    }

    function outputPath(Version version_) internal returns (string memory) {
        string memory chainName = getChainAlias();
        return outputPath(chainName, version_);
    }

    function outputPath(string memory chainName, Version version_)
        internal
        pure
        returns (string memory)
    {
        string memory version = version_ == Version.V0 ? "v0" : "v1";
        return string.concat(
            outputDir(chainName), "/", version, "-", "deployment.json"
        );
    }

    function mkdir(string memory dirPath) internal {
        string[] memory mkdirInputs = new string[](3);
        mkdirInputs[0] = "mkdir";
        mkdirInputs[1] = "-p";
        mkdirInputs[2] = dirPath;
        vm.ffi(mkdirInputs);
    }

    function initJson() private {
        initJson(Version.V0);
    }

    function initJson(Version version_) private {
        mkdir(outputDir());

        string memory json = "deploymentArtifact";
        string memory addresses = "addresses";

        string memory chainInfo = "chainInfo";
        chainInfo.serialize("chainId", uint256(0));
        chainInfo = chainInfo.serialize("deploymentBlock", uint256(0));

        if (version_ == Version.V0) {
            addresses.serialize("queryClient", address(0));

            string memory storageContracts = "storageContracts";
            storageContracts.serialize("erc721Enumerable", address(0));
            storageContracts.serialize("erc20ProportionateBalance", address(0));
            storageContracts =
                storageContracts.serialize("erc20AvgBalance", address(0));

            json.serialize("storageContracts", storageContracts);
        } else if (version_ == Version.V1) {
            addresses.serialize("queryClientImpl", address(0));
            addresses.serialize("queryClientProxy", address(0));
        } else {
            require(false, "Unsupported Contract Version");
        }

        addresses.serialize("registryImpl", address(0));
        addresses = addresses.serialize("registryProxy", address(0));

        json.serialize("addresses", addresses);
        json = json.serialize("chainInfo", chainInfo);

        json.write(outputPath(version_));
    }
}
