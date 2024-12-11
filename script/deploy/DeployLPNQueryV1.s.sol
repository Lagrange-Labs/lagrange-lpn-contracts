// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseDeployer} from "../BaseDeployer.s.sol";
import {LPNQueryV1} from "../../src/v1/client/LPNQueryV1.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {isLocal, isMainnet} from "../../src/utils/Constants.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ILPNRegistryV1} from "../../src/v1/interfaces/ILPNRegistryV1.sol";

contract DeployLPNQueryV1 is BaseDeployer {
    using stdJson for string;

    struct Deployment {
        LPNQueryV1 queryProxy;
        address queryImpl;
    }

    Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    function run() external returns (Deployment memory) {
        if (getDeployedQueryClient(Version.V1) == address(0)) {
            deployment.queryImpl = deployImplementation();

            address owner = isMainnet() ? address(SAFE) : deployer;

            bytes32 salt = newSalt(vm.envString("SALT"));

            deployment.queryProxy =
                LPNQueryV1(deployProxy(deployment.queryImpl, salt, owner));

            writeToJson();
        } else {
            deployment.queryImpl = deployImplementation();
            upgrade(
                LPNQueryV1(getDeployedQueryClient(Version.V1)),
                deployment.queryImpl
            );

            writeToJson(deployment.queryImpl);
        }

        return deployment;
    }

    /// @dev Deploy a new implementation contract
    function deployImplementation() public broadcaster returns (address) {
        address queryImpl = address(new LPNQueryV1());
        print("LPNQueryV1 (implementation)", address(queryImpl));
        return queryImpl;
    }

    /// @dev Deploy a new proxy pointing to the implementation
    /// @dev The deployer is the admin of the proxy and is authorized to upgrade the proxy
    function deployProxy(address queryImpl, bytes32 salt_, address owner)
        public
        broadcaster
        returns (address)
    {
        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }
        address queryProxy = proxyFactory.deployDeterministicAndCall(
            queryImpl,
            owner,
            salt_,
            abi.encodeWithSelector(
                LPNQueryV1.initialize.selector,
                ILPNRegistryV1(getDeployedRegistry(Version.V1))
            )
        );

        print("LPNQueryV1 (proxy)", queryProxy);

        return queryProxy;
    }

    /// @dev Update proxy to point to new implementation contract
    /// @dev On mainnets, this proposes a tx to the multisig
    /// @dev On testnets, this directly sends a tx onchain
    function upgrade(LPNQueryV1 proxy, address queryImpl) public {
        if (isMainnet()) {
            upgradeMainnet(proxy, queryImpl);
        } else {
            upgradeHolesky(proxy, queryImpl);
        }
    }

    function upgradeMainnet(LPNQueryV1 proxy, address queryImpl)
        internal
        isBatch(address(SAFE))
    {
        bytes memory txn = abi.encodeWithSelector(
            ERC1967Factory.upgrade.selector, address(proxy), queryImpl
        );

        addToBatch(address(proxyFactory), txn);
        executeBatch(true);
    }

    function upgradeHolesky(LPNQueryV1 proxy, address queryImpl)
        public
        broadcaster
    {
        if (isLocal()) {
            vm.etch(
                ERC1967FactoryConstants.ADDRESS,
                ERC1967FactoryConstants.BYTECODE
            );
        }

        proxyFactory.upgrade(address(proxy), queryImpl);
    }

    function writeToJson() private {
        vm.writeJson(
            vm.toString(address(deployment.queryProxy)),
            outputPath(Version.V1),
            ".addresses.queryClientProxy"
        );

        vm.writeJson(
            vm.toString(deployment.queryImpl),
            outputPath(Version.V1),
            ".addresses.queryClientImpl"
        );
    }

    function writeToJson(address updatedQueryImpl) private {
        vm.writeJson(
            vm.toString(updatedQueryImpl),
            outputPath(Version.V1),
            ".addresses.queryClientImpl"
        );
    }
}
