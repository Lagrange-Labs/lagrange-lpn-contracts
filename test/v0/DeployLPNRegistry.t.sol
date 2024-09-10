// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LPNRegistryV0} from "../../src/v0/LPNRegistryV0.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {DeployLPNRegistryV0} from
    "../../script/deploy/v0/DeployLPNRegistryV0.s.sol";

import {DeployERC1967ProxyFactory} from
    "../../script/deploy/DeployERC1967ProxyFactory.s.sol";

contract DeployLPNRegistryTest is Test {
    DeployLPNRegistryV0 public deployScript = new DeployLPNRegistryV0();
    DeployLPNRegistryV0.Deployment deployment;

    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    bytes32 salt;
    address owner = address(deployScript);

    function setUp() public {
        vm.etch(
            ERC1967FactoryConstants.ADDRESS, ERC1967FactoryConstants.BYTECODE
        );
        salt = bytes32(abi.encodePacked(address(deployScript), "LPN_V0_TEST"));
    }

    function testDeploy() public {
        deployment = deployScript.deploy(salt, owner);

        assertEq(deployment.registryProxy.owner(), owner);
        assert(address(deployment.registryProxy) != address(0));
    }

    function testUpgrade() public {
        deployment = deployScript.deploy(salt, owner);
        address oldImpl = deployment.registryImpl;

        proxyFactory.adminOf(address(deployment.registryProxy));

        address newImpl =
            deployScript.upgrade(address(deployment.registryProxy));

        assert(oldImpl != newImpl);
        assertEq(deployment.registryProxy.owner(), owner);
    }

    function testProxyOwnership() public {
        deployment = deployScript.deploy(salt, owner);

        assertEq(proxyFactory.adminOf(address(deployment.registryProxy)), owner);
    }

    function testProxyInitialization() public {
        deployment = deployScript.deploy(salt, owner);

        assertEq(deployment.registryProxy.owner(), owner);
    }

    function testDeterministicDeployment() public {
        deployScript.deploy(salt, owner);

        vm.expectRevert(ERC1967Factory.DeploymentFailed.selector);
        deployScript.deploy(salt, owner);
    }

    function testDeployWithDifferentSalt() public {
        deployment = deployScript.deploy(salt, owner);

        bytes32 newSalt =
            bytes32(abi.encodePacked(address(deployScript), "LPN_V1"));

        DeployLPNRegistryV0.Deployment memory newDeployment =
            deployScript.deploy(newSalt, owner);

        assert(deployment.registryProxy != newDeployment.registryProxy);
    }
}
