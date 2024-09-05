// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseScript} from "../BaseScript.s.sol";
import {LPNQueryV1} from "../../src/v1/client/LPNQueryV1.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {isLocal} from "../../src/utils/Constants.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ILPNRegistryV1} from "../../src/v1/interfaces/ILPNRegistryV1.sol";

contract DeployLPNQueryV1 is BaseScript {
    using stdJson for string;

    struct Deployment {
        LPNQueryV1 queryProxy;
        address queryImpl;
    }

    Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    function run() external broadcaster returns (Deployment memory) {
        if (getDeployedQueryClient(Version.V1) == address(0)) {
            deployment = deploy(newSalt("V1_QUERY_0"), deployer);
            writeToJson();
        } else {
            address updatedQueryImpl =
                upgrade(getDeployedQueryClient(Version.V1));
            writeToJson(updatedQueryImpl);
        }

        assertions();

        return deployment;
    }

    function deploy(bytes32 salt_, address owner)
        public
        returns (Deployment memory)
    {
        // Deploy a new implementation
        address queryImpl = address(new LPNQueryV1());
        print("LPNQueryV1 (implementation)", address(queryImpl));

        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }

        // Get the LPNRegistryV1 address
        address lpnRegistry = getDeployedRegistry(Version.V1);
        require(lpnRegistry != address(0), "LPNRegistry not deployed");

        // Deploy a new proxy pointing to the implementation
        address queryProxy = proxyFactory.deployDeterministicAndCall(
            queryImpl,
            owner,
            salt_,
            abi.encodeWithSelector(
                LPNQueryV1.initialize.selector, ILPNRegistryV1(lpnRegistry)
            )
        );
        print("LPNQueryV1 (proxy)", address(queryProxy));

        return Deployment({
            queryProxy: LPNQueryV1(queryProxy),
            queryImpl: queryImpl
        });
    }

    function upgrade(address proxy) public returns (address) {
        // Deploy a new implementation
        address queryImpl = address(new LPNQueryV1());
        print("LPNQueryV1 (implementation)", address(queryImpl));

        // Update proxy to point to new implementation contract
        proxyFactory.upgrade(proxy, queryImpl);
        return queryImpl;
    }

    function assertions() private view {}

    function writeToJson() private {
        mkdir(outputDir());

        string memory json = "deploymentArtifact";

        string memory addresses = "addresses";
        addresses.serialize("queryImpl", deployment.queryImpl);
        addresses =
            addresses.serialize("queryProxy", address(deployment.queryProxy));

        string memory chainInfo = "chainInfo";
        chainInfo.serialize("chainId", block.chainid);
        chainInfo = chainInfo.serialize("deploymentBlock", block.number);

        json.serialize("addresses", addresses);
        json = json.serialize("chainInfo", chainInfo);

        json.write(outputPath(Version.V1));
    }

    function writeToJson(address updatedQueryImpl) private {
        vm.writeJson(
            vm.toString(updatedQueryImpl),
            outputPath(Version.V1),
            ".addresses.queryImpl"
        );
    }
}
