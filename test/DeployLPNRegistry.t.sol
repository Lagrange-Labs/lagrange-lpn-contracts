// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LPNRegistryV0} from "../src/LPNRegistryV0.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC1967FactoryConstants} from "solady/utils/ERC1967FactoryConstants.sol";
import {DeployLPNRegistry} from "../script/DeployLPNRegistry.s.sol";

contract DeployLPNRegistryTest is Test {
    DeployLPNRegistry public deployScript = new DeployLPNRegistry();
    LPNRegistryV0 registry;
    ERC1967Factory proxyFactory =
        ERC1967Factory(ERC1967FactoryConstants.ADDRESS);

    address registryImpl;
    address registryProxy;
    bytes32 salt;

    function setUp() public {
        salt = bytes32(abi.encodePacked(deployScript.deployer(), "LPN_V0_TEST"));
    }

    function testDeploy() public {
        (registry, registryImpl) = deployScript.deploy(salt);
        registryProxy = address(registry);

        assertEq(registry.owner(), deployScript.deployer());
        assert(registryProxy != address(0));
    }

    function testUpgrade() public {
        (registry, registryImpl) = deployScript.deploy(salt);
        registryProxy = address(registry);
        address oldImpl = registryImpl;

        address newImpl = deployScript.upgrade(registryProxy);

        assert(oldImpl != newImpl);
        assertEq(registry.owner(), address(deployScript.deployer()));
    }

    function testProxyOwnership() public {
        (registry, registryImpl) = deployScript.deploy(salt);
        registryProxy = address(registry);

        assertEq(
            proxyFactory.adminOf(registryProxy),
            address(deployScript.deployer())
        );
    }

    function testProxyInitialization() public {
        (registry,) = deployScript.deploy(salt);

        assertEq(registry.owner(), deployScript.deployer());
    }

    function testDeterministicDeployment() public {
        (registry,) = deployScript.deploy(salt);
        registryProxy = address(registry);

        vm.expectRevert(ERC1967Factory.DeploymentFailed.selector);
        deployScript.deploy(salt);
    }

    function testDeployWithDifferentSalt() public {
        (registry,) = deployScript.deploy(salt);
        registryProxy = address(registry);

        bytes32 newSalt =
            bytes32(abi.encodePacked(deployScript.deployer(), "LPN_V1"));
        (LPNRegistryV0 newRegistry,) = deployScript.deploy(newSalt);
        address newRegistryProxy = address(newRegistry);

        assert(registryProxy != newRegistryProxy);
    }
}
