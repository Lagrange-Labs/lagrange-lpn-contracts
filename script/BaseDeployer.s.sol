// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, console2, StdChains} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {BatchScript} from "forge-safe/BatchScript.sol";
import {ISafe} from "safe-smart-account/interfaces/ISafe.sol";
import {ChainConnections} from "../src/utils/ChainConnections.sol";
import {isMainnet} from "../src/utils/Constants.sol";

abstract contract BaseDeployer is BatchScript, ChainConnections {
    using stdJson for string;

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
        if (isMainnet()) {
            vm.startBroadcast();
            (, deployer,) = vm.readCallers();
            vm.stopBroadcast();
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

    function getDeployedRegistry() internal returns (address) {
        string memory json = vm.readFile(outputPath());
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
        return outputPath(getChainAlias());
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

    function initJson() private {
        mkdir(outputDir());

        string memory json = "deploymentArtifact";
        string memory addresses = "addresses";

        string memory chainInfo = "chainInfo";
        chainInfo.serialize("chainId", uint256(0));
        chainInfo = chainInfo.serialize("deploymentBlock", uint256(0));

        addresses.serialize("queryClientImpl", address(0));
        addresses.serialize("queryClientProxy", address(0));

        addresses.serialize("registryImpl", address(0));
        addresses = addresses.serialize("registryProxy", address(0));

        json.serialize("addresses", addresses);
        json = json.serialize("chainInfo", chainInfo);

        json.write(outputPath());
    }
}
